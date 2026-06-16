/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ported from Zotero Desktop (AGPL-3.0)
 *
 * Ref: xpcom/sync/syncLocal.js — API key, sync queue, delete log, cache
 *
 * ***** END LICENSE BLOCK *****
 */

/**
 * Entry in the sync queue for objects that failed and need retry.
 * Ref: syncLocal.js:30-31 (_syncQueueIntervals)
 */
export interface SyncQueueEntry {
  key: string;
  objectType: string;
  libraryID: number;
  tries: number;
  lastTryTimestamp: number;
}

/** Retry intervals in milliseconds: [0.5h, 1h, 4h, 16h×7, 64h]. */
export const SYNC_QUEUE_INTERVALS_MS: number[] = [
  30 * 60 * 1000,      // 0.5h
  60 * 60 * 1000,      // 1h
  4 * 60 * 60 * 1000,  // 4h
  16 * 60 * 60 * 1000, // 16h (repeated 8 times)
  64 * 60 * 60 * 1000, // 64h
];

/**
 * In-memory sync state manager — runtime retry & cache layer.
 *
 * Manages: API key, retry queue, download cache, last-sync timestamp.
 *
 * Persistence boundary:
 *   - The authoritative local change queue (`syncQueue`) and delete log
 *     (`syncDeleteLog`) are now SQLite-backed via LibraryRepository.
 *   - This class retains its role as an in-memory retry tracker and
 *     download-object cache used by SyncEngine.
 *   - When SyncEngine._startUpload() is implemented, it should read from
 *     LibraryRepository's persistent syncQueue / syncDeleteLog, not from here.
 *
 * Ref: syncLocal.js:30-88
 */
export class SyncLocalState {
  private apiKey: string | null = null;
  private syncQueue: Map<string, SyncQueueEntry> = new Map();
  private deleteLogs: Map<string, Set<string>> = new Map();
  private lastSyncTimestamp: number | null = null;

  // ==================================================================
  // API Key  Ref: syncLocal.js:49-88
  // ==================================================================

  async getApiKey(): Promise<string | null> {
    return this.apiKey;
  }

  async setApiKey(key: string | null): Promise<void> {
    this.apiKey = key;
  }

  // ==================================================================
  // Sync Queue  Ref: syncLocal.js: sync queue management
  // ==================================================================

  /** Build key for queue lookup. */
  private _qKey(libraryID: number, objectType: string, key: string): string {
    return `${libraryID}/${objectType}/${key}`;
  }

  async addToSyncQueue(libraryID: number, objectType: string, keys: string[]): Promise<void> {
    let now = Date.now();
    for (let i = 0; i < keys.length; i++) {
      let qk = this._qKey(libraryID, objectType, keys[i]);
      let existing = this.syncQueue.get(qk);
      this.syncQueue.set(qk, {
        key: keys[i], objectType, libraryID,
        tries: existing ? existing.tries + 1 : 0,
        lastTryTimestamp: now,
      });
    }
  }

  async removeFromSyncQueue(libraryID: number, objectType: string, keys: string[]): Promise<void> {
    for (let i = 0; i < keys.length; i++) {
      this.syncQueue.delete(this._qKey(libraryID, objectType, keys[i]));
    }
  }

  async getObjectsToRetry(libraryID: number, objectType: string): Promise<string[]> {
    let now = Date.now();
    let result: string[] = [];
    this.syncQueue.forEach((entry: SyncQueueEntry, qKey: string) => {
      if (entry.libraryID !== libraryID || entry.objectType !== objectType) { return; }
      let interval = SYNC_QUEUE_INTERVALS_MS[
        Math.min(entry.tries, SYNC_QUEUE_INTERVALS_MS.length - 1)
      ];
      if (now - entry.lastTryTimestamp >= interval) {
        result.push(entry.key);
      }
    });
    return result;
  }

  async getAllObjectsInQueue(libraryID: number, objectType: string): Promise<string[]> {
    let result: string[] = [];
    this.syncQueue.forEach((entry: SyncQueueEntry, qKey: string) => {
      if (entry.libraryID === libraryID && entry.objectType === objectType) {
        result.push(entry.key);
      }
    });
    return result;
  }

  // ==================================================================
  // Delete Log  Ref: syncLocal.js  getDeleted / removeObjectsFromDeleteLog
  // ==================================================================

  async addToDeleteLog(libraryID: number, objectType: string, keys: string[]): Promise<void> {
    let logKey = `${libraryID}/${objectType}`;
    let set = this.deleteLogs.get(logKey) ?? new Set();
    for (let i = 0; i < keys.length; i++) { set.add(keys[i]); }
    this.deleteLogs.set(logKey, set);
  }

  async removeFromDeleteLog(libraryID: number, objectType: string, keys: string[]): Promise<void> {
    let logKey = `${libraryID}/${objectType}`;
    let set = this.deleteLogs.get(logKey);
    if (!set) { return; }
    for (let i = 0; i < keys.length; i++) { set.delete(keys[i]); }
    if (set.size === 0) { this.deleteLogs.delete(logKey); }
  }

  async getDeleted(libraryID: number, objectType: string): Promise<string[]> {
    let logKey = `${libraryID}/${objectType}`;
    let set = this.deleteLogs.get(logKey);
    return set ? Array.from(set) : [];
  }

  // ==================================================================
  // Sync timestamp  Ref: syncLocal.js:35-43
  // ==================================================================

  getLastSyncTime(): number | null { return this.lastSyncTimestamp; }

  async updateLastSyncTime(): Promise<void> {
    this.lastSyncTimestamp = Date.now();
  }

  // ==================================================================
  // Cache objects (store downloaded JSON for later retry)
  // Ref: syncLocal.js  saveCacheObjects / getCacheObject / purgeCache
  // ==================================================================

  private _cache: Map<string, string> = new Map();

  async saveCacheObjects(
    libraryID: number, objectType: string, objects: Record<string, Object>[]
  ): Promise<void> {
    for (let i = 0; i < objects.length; i++) {
      let obj = objects[i];
      let key = (obj['key'] ?? '') as string;
      if (key) {
        this._cache.set(`${libraryID}/${objectType}/${key}`, JSON.stringify(obj));
      }
    }
  }

  async getCacheObject(libraryID: number, objectType: string, key: string): Promise<Record<string, Object> | null> {
    let raw = this._cache.get(`${libraryID}/${objectType}/${key}`);
    return raw ? JSON.parse(raw) as Record<string, Object> : null;
  }

  async purgeCache(libraryID: number, objectType: string): Promise<void> {
    let prefix = `${libraryID}/${objectType}/`;
    let toDelete: string[] = [];
    this._cache.forEach((_v: string, k: string) => { if (k.startsWith(prefix)) { toDelete.push(k); } });
    for (let i = 0; i < toDelete.length; i++) { this._cache.delete(toDelete[i]); }
  }
}
