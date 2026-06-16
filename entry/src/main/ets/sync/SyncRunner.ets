/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ported from Zotero Desktop (AGPL-3.0)
 *
 * Ref: xpcom/sync/syncRunner.js — multi-library orchestrator
 *
 * ***** END LICENSE BLOCK *****
 */

import { ZoteroAPI } from '../api/ZoteroAPI.ets';
import { ZoteroAPIUpload } from '../api/ZoteroAPIUpload.ets';
import { HttpClient } from '../api/HttpClient.ets';
import { SyncLocalState } from './SyncLocalState.ets';
import { SyncEngine, SyncLibrary } from './SyncEngine.ets';
import { UserCancelledException } from './SyncExceptions.ets';
import { FileSyncEngine } from './FileSyncEngine.ets';
import { StorageResult } from './StorageResult.ets';

/** Sync status reported to UI. */
export interface SyncStatus {
  state: 'idle' | 'syncing' | 'downloading' | 'uploading' | 'error' | 'success';
  message: string;
  lastSyncTimestamp: number | null;
  errors: string[];
}

/**
 * Top-level sync runner — authentication, library discovery, and
 * sequential library-by-library data + file sync.
 *
 * Ref: syncRunner.js:33-341  constructor / _sync
 */
export class SyncRunner {
  private api: ZoteroAPI;
  private apiUpload: ZoteroAPIUpload;
  private state: SyncLocalState;
  private status: SyncStatus;
  private appContext: Context | null = null;

  constructor(baseURL: string, appContext?: Context) {
    let http = new HttpClient(baseURL);
    this.api = new ZoteroAPI(http);
    this.apiUpload = new ZoteroAPIUpload(http);
    this.state = new SyncLocalState();
    this.status = {
      state: 'idle', message: '', lastSyncTimestamp: null, errors: [],
    };
    this.appContext = appContext ?? null;
  }

  get syncStatus(): SyncStatus { return this.status; }

  /** Set API key (e.g. after login flow). Ref: syncRunner.js:1646-1669 */
  async loginWithApiKey(apiKey: string): Promise<void> {
    await this.state.setApiKey(apiKey);
    this.api.getHttp().setApiKey(apiKey);
  }

  // ==================================================================
  // Main sync  Ref: syncRunner.js:116-341  _sync
  // ==================================================================

  async sync(background: boolean = false): Promise<boolean> {
    this.status = { state: 'syncing', message: 'Preparing…', lastSyncTimestamp: null, errors: [] };

    try {
      // 1. Verify API key
      let apiKey = await this.state.getApiKey();
      if (!apiKey) {
        this.status.message = 'Not logged in — API key not set';
        this.status.state = 'error';
        return false;
      }

      // 2. Get key info / user identity
      let keyInfo = await this.api.getKeyInfo();
      if (!keyInfo) {
        throw new Error('Invalid API key');
      }

      // 3. Discover libraries to sync
      let libraries = await this._discoverLibraries(keyInfo.userID);

      // 4. Sync each library
      let attempt = 1;
      let remaining = [...libraries];
      while (remaining.length > 0 && attempt <= 3) {
        this.status.message = `Syncing (attempt ${attempt})…`;
        let nextRemaining: SyncLibrary[] = [];

        for (let i = 0; i < remaining.length; i++) {
          let lib = remaining[i];
          this.status.message = `Syncing ${lib.name}…`;
          try {
            let engine = new SyncEngine(this.api, this.apiUpload, lib, this.state, this.appContext);
            await engine.start();
            await this._runFileSync();
          } catch (err) {
            if (err instanceof UserCancelledException && err.advanceToNextLibrary) {
              continue;
            }
            this.status.errors.push(`Sync failed for ${lib.name}`);
            nextRemaining.push(lib);
          }
        }
        remaining = nextRemaining;
        attempt++;
      }
      await this.state.updateLastSyncTime();
      let hasFileErrors = this.status.errors.length > 0;
      this.status = {
        state: remaining.length === 0 && !hasFileErrors ? 'success' : 'error',
        message: remaining.length === 0 ? (hasFileErrors ? 'Done with file-sync errors' : 'Done') : `${remaining.length} libraries failed`,
        lastSyncTimestamp: this.state.getLastSyncTime(),
        errors: this.status.errors,
      };
      return remaining.length === 0 && !hasFileErrors;
    } catch (err) {
      this.status = {
        state: 'error',
        message: (err as Error).message ?? 'Unknown error',
        lastSyncTimestamp: null,
        errors: [...this.status.errors, (err as Error).message],
      };
      return false;
    }
  }

  // ==================================================================
  // Auto-sync timer  Ref: syncRunner.js:962-1043
  // ==================================================================

  private autoSyncTimerID: number | null = null;

  /**
   * Start recurring auto-sync. intervalSeconds=0 stops.
   */
  startAutoSync(intervalSeconds: number): void {
    this.stopAutoSync();
    if (intervalSeconds <= 0) { return; }
    this.autoSyncTimerID = setInterval(() => {
      this.sync(true);
    }, intervalSeconds * 1000);
  }

  stopAutoSync(): void {
    if (this.autoSyncTimerID !== null) {
      clearInterval(this.autoSyncTimerID);
      this.autoSyncTimerID = null;
    }
  }

  // ==================================================================
  // Private
  // ==================================================================

  /**
   * Discover libraries the user has access to.
   * Ref: syncRunner.js:415-639  checkLibraries
   */
  private async _discoverLibraries(userID: number): Promise<SyncLibrary[]> {
    let libraries: SyncLibrary[] = [];

    // My Library
    let keyInfo = await this.api.getKeyInfo();
    if (keyInfo && keyInfo.access['user'] !== undefined) {
      libraries.push({
        libraryID: 1, libraryType: 'user', libraryTypeID: userID,
        libraryVersion: 0, storageVersion: 0, name: 'My Library',
      });
    }

    // Groups
    try {
      let groupVersions = await this.api.getGroupVersions(userID);
      let groupIDs = Object.keys(groupVersions);
      for (let i = 0; i < groupIDs.length; i++) {
        let gid = parseInt(groupIDs[i]);
        let meta = await this.api.getGroup(gid);
        if (meta) {
          let metaObj = meta as Record<string, Object>;
          let libID = (metaObj.libraryID ?? 0) as number;
          libraries.push({
            libraryID: libID, libraryType: 'group', libraryTypeID: gid,
            libraryVersion: groupVersions.get(gid) ?? 0,
            storageVersion: 0,
            name: (metaObj.name ?? `Group ${gid}`) as string,
          });
        }
      }
    } catch (_e) { /* group access may be denied */ }

    return libraries;
  }

  private async _runFileSync(): Promise<void> {
    if (!this.appContext) {
      return;
    }
    this.status.state = 'downloading';
    this.status.message = 'Syncing attachment files…';
    let results = await new FileSyncEngine(this.appContext).runPending();
    let failed = 0;
    for (let i = 0; i < results.length; i++) {
      if (results[i].state === 'error') {
        failed++;
        this.status.errors.push(this.fileSyncErrorMessage(results[i]));
      }
    }
    if (failed > 0) {
      this.status.message = `${failed} attachment files need a configured file-sync backend`;
    }
  }

  private fileSyncErrorMessage(result: StorageResult): string {
    return result.itemKey.length > 0 ? `${result.itemKey}: ${result.message}` : result.message;
  }
}
