/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ported from Zotero Desktop (AGPL-3.0)
 * Original: chrome/content/zotero/xpcom/data/creators.js
 *
 * ***** END LICENSE BLOCK *****
 */

import { ZoteroCreator } from './ItemTypes.ets';

/**
 * Clean and normalize creator data.
 * Ref: creators.js:68-79  cleanData()
 */
function cleanData(raw: ZoteroCreator): ZoteroCreator {
  return {
    creatorType: raw.creatorType,
    firstName: raw.firstName ?? '',
    lastName: raw.lastName ?? '',
    fieldMode: raw.fieldMode ?? 0,
  };
}

/**
 * In-memory creator cache.
 * Original used a plain object {}. Ported to Map for stricter typing.
 *
 * Ref: creators.js:27-31  Zotero.Creators constructor
 * Ref: creators.js:68-79  get(id)
 */
export class CreatorCache {
  private cache: Map<number, ZoteroCreator> = new Map();

  /**
   * Return a copy of creator data for the given ID.
   * Throws if not found — matches original behaviour (creators.js:73-76).
   * Ref: creators.js:68-79
   */
  get(id: number): ZoteroCreator {
    if (!id) {
      throw new Error('creatorID not provided');
    }
    let entry = this.cache.get(id);
    if (!entry) {
      throw new Error(`Creator ${id} not found in cache`);
    }
    // Return a shallow copy (ref: creators.js:78  this.cleanData(...))
    return cleanData(entry);
  }

  /**
   * Store a creator.
   * Ref: creators.js  row → _cache[row.creatorID] = cleanData({...})
   */
  set(id: number, creator: ZoteroCreator): void {
    this.cache.set(id, cleanData(creator));
  }

  /**
   * Remove a creator from the cache.
   */
  delete(id: number): boolean {
    return this.cache.delete(id);
  }

  /**
   * Bulk load from an array of [id, creator] entries.
   */
  load(entries: Array<[number, ZoteroCreator]>): void {
    for (let i = 0; i < entries.length; i++) {
      let item = entries[i];
      this.set(item[0], item[1]);
    }
  }

  /**
   * Clear all cached entries.
   * Ref: creators.js:34  _cache = {}
   */
  clear(): void {
    this.cache.clear();
  }

  /**
   * Return the number of cached creators.
   */
  get size(): number {
    return this.cache.size;
  }
}
