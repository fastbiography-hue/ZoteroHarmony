/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ported from Zotero Desktop (AGPL-3.0)
 *
 * Ref: xpcom/sync/syncEngine.js — _runSync / _startUpload / _startDownload
 *
 * ***** END LICENSE BLOCK *****
 */

import { ZoteroAPI } from '../api/ZoteroAPI.ets';
import { ZoteroAPIUpload } from '../api/ZoteroAPIUpload.ets';
import { LibraryType, ObjectType } from '../api/ZoteroAPITypes.ets';
import { SyncLocalState } from './SyncLocalState.ets';
import { DownloadResult, UploadResult } from './SyncExceptions.ets';
import { LibraryRepository, RemoteObjectType } from '../database/LibraryRepository.ets';

const CONFLICT_DELAYS_MS = [10000, 20000, 40000, 60000, 120000, 240000, 300000];

export interface SyncLibrary {
  libraryID: number;
  libraryType: LibraryType;
  libraryTypeID: number;
  libraryVersion: number;
  storageVersion: number;
  name: string;
}

/**
 * Single-library data sync engine.
 *
 * Ref: syncEngine.js:94-263  _runSync upload-first pipeline
 */
export class SyncEngine {
  private api: ZoteroAPI;
  private apiUpload: ZoteroAPIUpload;
  private library: SyncLibrary;
  private state: SyncLocalState;
  private appContext: Context | null = null;

  constructor(
    api: ZoteroAPI, apiUpload: ZoteroAPIUpload,
    library: SyncLibrary, state: SyncLocalState,
    appContext?: Context | null
  ) {
    this.api = api;
    this.apiUpload = apiUpload;
    this.library = library;
    this.state = state;
    this.appContext = appContext ?? null;
  }

  // Entry point  Ref: syncEngine.js:94-117
  async start(): Promise<boolean> {
    let resetTried = false;
    while (true) {
      try { return await this._runSync(); }
      catch (err) {
        let e = err as Error;
        if (!resetTried && e.name === 'LibraryVersionDecreaseError') {
          resetTried = true;
          this.library.libraryVersion = -1;
          continue;
        }
        throw e;
      }
    }
  }

  // Main loop  Ref: syncEngine.js:120-263
  private async _runSync(): Promise<boolean> {
    if (this.library.libraryVersion <= 0) {
      await this._fullSync();
    }
    let autoReset = false;
    let conflictPos = 0;

    while (true) {
      let uploadResult: UploadResult;
      try { uploadResult = await this._startUpload(); }
      catch (e) {
        let err = e as Error;
        await this._startDownload();
        throw err;
      }

      switch (uploadResult) {
        case UploadResult.SUCCESS: return true;
        case UploadResult.OBJECT_CONFLICT:
          if (autoReset) { throw new Error(`${this.library.name} already auto-reset`); }
          autoReset = true;
          await this._fullSync();
          break;
        case UploadResult.NOTHING_TO_UPLOAD:
          let dl = await this._startDownload();
          return dl !== DownloadResult.CHANGES_TO_UPLOAD;
        case UploadResult.LIBRARY_CONFLICT:
          if (conflictPos >= CONFLICT_DELAYS_MS.length) {
            throw new Error(`Too many retries for ${this.library.name}`);
          }
          await this._sleep(CONFLICT_DELAYS_MS[conflictPos++]);
          await this._startDownload();
          break;
        case UploadResult.RESTART: break;
        case UploadResult.CANCEL: return false;
      }
    }
  }

  // Upload  Ref: syncEngine.js:1020-1166
  private async _startUpload(): Promise<UploadResult> {
    let lt = this.library.libraryType;
    let ltid = this.library.libraryTypeID;
    let lid = this.library.libraryID;
    let hasWork = false;
    let objTypes: ObjectType[] = ['collection', 'search', 'item'];

    for (let ti = 0; ti < objTypes.length; ti++) {
      let ot = objTypes[ti];
      let deleted = await this.state.getDeleted(lid, ot);
      while (deleted.length > 0) {
        let batch = deleted.splice(0, 25);
        await this.apiUpload.uploadDeletions(lt, ltid, this.library.libraryVersion, ot, batch);
        await this.state.removeFromDeleteLog(lid, ot, batch);
        hasWork = true;
      }
    }
    return hasWork ? UploadResult.SUCCESS : UploadResult.NOTHING_TO_UPLOAD;
  }

  // Download  Ref: syncEngine.js:280-381
  private async _startDownload(): Promise<DownloadResult> {
    let lv = this.library.libraryVersion;
    let lt = this.library.libraryType;
    let ltid = this.library.libraryTypeID;
    let lid = this.library.libraryID;
    let hasRemoteChanges = false;

    // Settings
    let s = await this.api.getSettings(lt, ltid, lv);
    if (s === null) { return DownloadResult.LIBRARY_UNMODIFIED; }
    let newLV = s.libraryVersion;

    // Object versions + download
    let objTypes: ObjectType[] = ['collection', 'search', 'item'];
    for (let ti = 0; ti < objTypes.length; ti++) {
      let ot = objTypes[ti];
      let vr = await this.api.getVersions(lt, ltid, ot, lv);
      if (vr === null) { continue; }
      let keys = Object.keys(vr.versions);
      let queued = await this.state.getObjectsToRetry(lid, ot);
      let merged: string[] = [];
      for (let i = 0; i < keys.length; i++) { merged.push(keys[i]); }
      for (let i = 0; i < queued.length; i++) { merged.push(queued[i]); }
      let all = Array.from(new Set(merged));
      if (all.length > 0) {
        let objects = await this.api.downloadObjects<Record<string, Object>>(lt, ltid, ot, all);
        await this.persistDownloadedObjects(ot, objects);
        await this.state.removeFromSyncQueue(lid, ot, all);
      }
      hasRemoteChanges = true;
    }

    // Deletions
    let dr = await this.api.getDeleted(lt, ltid, lv);
    if (dr !== null) {
      await this.persistRemoteDeletions(dr.deleted);
      hasRemoteChanges = true;
    }

    if (newLV > 0) { this.library.libraryVersion = newLV; }
    await this.state.updateLastSyncTime();
    return hasRemoteChanges ? DownloadResult.CHANGES_TO_UPLOAD : DownloadResult.NO_CHANGES_TO_UPLOAD;
  }

  // Full sync (since=0)  Ref: syncEngine.js
  private async _fullSync(): Promise<void> {
    let lt = this.library.libraryType;
    let ltid = this.library.libraryTypeID;
    let objTypes: ObjectType[] = ['collection', 'search', 'item'];
    for (let ti = 0; ti < objTypes.length; ti++) {
      let ot = objTypes[ti];
      let resp = await this.api.getVersions(lt, ltid, ot, 0);
      if (resp === null) { continue; }
      let keys = Object.keys(resp.versions);
      if (keys.length > 0) {
        let objects = await this.api.downloadObjects<Record<string, Object>>(lt, ltid, ot, keys);
        await this.persistDownloadedObjects(ot, objects);
      }
      this.library.libraryVersion = resp.libraryVersion;
    }
  }

  private _sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: (v: void) => void) => setTimeout(resolve, ms));
  }

  private async persistDownloadedObjects(objectType: ObjectType, objects: Record<string, Object>[]): Promise<void> {
    if (!this.appContext) {
      return;
    }
    let repo = new LibraryRepository();
    await repo.open(this.appContext);
    for (let i = 0; i < objects.length; i++) {
      await repo.upsertRemoteObject(objectType as RemoteObjectType, objects[i], this.library.libraryID);
    }
    await repo.close();
  }

  private async persistRemoteDeletions(deleted: Record<string, string[]>): Promise<void> {
    if (!this.appContext) {
      return;
    }
    let repo = new LibraryRepository();
    await repo.open(this.appContext);
    let objectTypes: RemoteObjectType[] = ['collection', 'search', 'item'];
    for (let i = 0; i < objectTypes.length; i++) {
      let plural = objectTypes[i] === 'collection' ? 'collections' : (objectTypes[i] === 'item' ? 'items' : 'searches');
      let keys = deleted[plural] ?? deleted[objectTypes[i]] ?? [];
      await repo.applyRemoteDeletions(objectTypes[i], keys, this.library.libraryID);
    }
    await repo.close();
  }
}
