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

  /**
   * Test-only entry point that directly invokes the upload pipeline
   * without the outer sync loop.  Exposed so tests can verify
   * upload behaviour in isolation.
   */
  async startUploadForTest(): Promise<UploadResult> {
    return this._startUpload();
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
  // Uses persistent syncQueue/syncDeleteLog via LibraryRepository.
  private async _startUpload(): Promise<UploadResult> {
    if (!this.appContext) {
      // Persistent queue requires appContext to open LibraryRepository.
      // Without it we have no authoritative upload source.
      return UploadResult.NOTHING_TO_UPLOAD;
    }

    let lt = this.library.libraryType;
    let ltid = this.library.libraryTypeID;
    let lid = this.library.libraryID;
    let objTypes: ObjectType[] = ['collection', 'search', 'item'];
    let hasWork = false;

    let repo = new LibraryRepository();
    await repo.open(this.appContext);
    try {
      // --- Phase 1: upload deletions ---
      for (let ti = 0; ti < objTypes.length; ti++) {
        let ot = objTypes[ti];
        let deleted = await repo.getDeleted(lid, ot);
        while (deleted.length > 0) {
          let batch = deleted.splice(0, 25);
          let newVersion = await this.apiUpload.uploadDeletions(
            lt, ltid, this.library.libraryVersion, ot, batch
          );
          this.library.libraryVersion = newVersion;
          await repo.removeFromDeleteLog(lid, ot, batch);
          hasWork = true;
        }
      }

      // --- Phase 2: upload upserts ---
      for (let ti = 0; ti < objTypes.length; ti++) {
        let ot = objTypes[ti];
        let queued = await repo.getAllObjectsInQueue(lid, ot);
        while (queued.length > 0) {
          let batchKeys = queued.splice(0, 25);
          let objects = await repo.getObjectsForUpload(lid, ot, batchKeys);
          if (objects.length === 0) {
            // Objects deleted locally after being queued — clean up
            await repo.removeFromSyncQueue(lid, ot, batchKeys);
            continue;
          }
          // Detect keys in batchKeys that are missing from objects
          let objectKeys = this.extractObjectKeys(objects);
          let missingKeys: string[] = [];
          for (let bi = 0; bi < batchKeys.length; bi++) {
            if (objectKeys.indexOf(batchKeys[bi]) < 0) {
              missingKeys.push(batchKeys[bi]);
            }
          }
          if (missingKeys.length > 0) {
            await repo.removeFromSyncQueue(lid, ot, missingKeys);
          }

          let response = await this.apiUpload.uploadObjects(
            lt, ltid, this.library.libraryVersion, ot, objects
          );
          this.library.libraryVersion = response.libraryVersion;

          let results = response.results;
          // Collect keys that were uploaded successfully
          let successfulKeys: string[] = [];
          for (let si = 0; si < results.successful.length; si++) {
            let succ = results.successful[si];
            let succKey = this.extractKey(succ);
            if (succKey.length > 0) { successfulKeys.push(succKey); }
          }
          // unchanged keys are already on the server
          let allDone = successfulKeys.concat(results.unchanged);
          await repo.removeFromSyncQueue(lid, ot, allDone);

          if (results.failed.length > 0) {
            // Leave failed keys in the queue for retry
            hasWork = true;
            return UploadResult.OBJECT_CONFLICT;
          }
          hasWork = true;
        }
      }
    } finally {
      await repo.close();
    }

    return hasWork ? UploadResult.SUCCESS : UploadResult.NOTHING_TO_UPLOAD;
  }

  /** Extract key from a single API object. */
  private extractKey(obj: Record<string, Object>): string {
    let data = obj['data'] as Record<string, Object> | undefined;
    let k: string = '';
    if (typeof data?.['key'] === 'string') { k = data!['key'] as string; }
    else if (typeof obj['key'] === 'string') { k = obj['key'] as string; }
    return k;
  }

  /** Extract keys from an array of API objects (supports wrapped and unwrapped). */
  private extractObjectKeys(objects: Record<string, Object>[]): string[] {
    let keys: string[] = [];
    for (let i = 0; i < objects.length; i++) {
      let obj = objects[i];
      let data = obj['data'] as Record<string, Object> | undefined;
      let k = (data?.['key'] ?? obj['key'] ?? '') as string;
      if (k.length > 0) { keys.push(k); }
    }
    return keys;
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
