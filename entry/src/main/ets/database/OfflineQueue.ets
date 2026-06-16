/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Offline write-ahead queue for changes made while disconnected.
 *
 * Queued operations are replayed in order when connectivity resumes.
 *
 * ***** END LICENSE BLOCK *****
 */

/** Operation types that can be queued. */
export type QueueOperation = 'create' | 'update' | 'delete';

/** One entry in the offline queue. */
export interface QueuedChange {
  id: number;
  timestamp: number;
  operation: QueueOperation;
  objectType: 'item' | 'collection' | 'search';
  objectKey: string | null;        // null = new object (not yet assigned)
  libraryID: number;
  payload: Record<string, Object>; // JSON serialized data object
}

/**
 * In-memory offline queue with persistence hooks.
 * In production, serialized to a SQLite table `offlineQueue`.
 */
export class OfflineQueue {
  private queue: QueuedChange[] = [];
  private nextID: number = 1;

  /**
   * Enqueue a change that happened while offline.
   */
  enqueue(
    operation: QueueOperation,
    objectType: 'item' | 'collection' | 'search',
    objectKey: string | null,
    libraryID: number,
    payload: Record<string, Object>
  ): number {
    let entry: QueuedChange = {
      id: this.nextID++, timestamp: Date.now(),
      operation, objectType, objectKey, libraryID, payload,
    };
    this.queue.push(entry);
    return entry.id;
  }

  /** Dequeue and return the next pending change, or null if empty. */
  dequeue(): QueuedChange | null {
    return this.queue.shift() ?? null;
  }

  /** Peek at the next pending change without removing. */
  peek(): QueuedChange | null {
    return this.queue.length > 0 ? this.queue[0] : null;
  }

  /** Number of pending changes. */
  get size(): number { return this.queue.length; }

  /** Get all pending changes for a specific library (for batch replay). */
  getByLibrary(libraryID: number): QueuedChange[] {
    return this.queue.filter((q: QueuedChange) => q.libraryID === libraryID);
  }

  /** Remove a specific entry by ID (after successful replay). */
  remove(id: number): boolean {
    let idx = this.queue.findIndex((q: QueuedChange) => q.id === id);
    if (idx >= 0) { this.queue.splice(idx, 1); return true; }
    return false;
  }

  /** Clear the entire queue. */
  clear(): void {
    this.queue = [];
  }

  /**
   * Serialize to JSON for persistence to disk/DB.
   * Call periodically and on app background.
   */
  serialize(): string {
    return JSON.stringify(this.queue);
  }

  /**
   * Restore from previously serialized JSON.
   */
  deserialize(json: string): void {
    try {
      let parsed = JSON.parse(json) as QueuedChange[];
      this.queue = Array.isArray(parsed) ? parsed : [];
      // Restore nextID from max existing id
      let max = 0;
      for (let i = 0; i < this.queue.length; i++) {
        if (this.queue[i].id > max) { max = this.queue[i].id; }
      }
      this.nextID = max + 1;
    } catch (_e) {
      this.queue = [];
    }
  }
}
