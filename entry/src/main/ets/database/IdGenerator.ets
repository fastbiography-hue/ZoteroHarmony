/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ported from Zotero Desktop (AGPL-3.0)
 * Original: chrome/content/zotero/xpcom/id.js
 *
 * ***** END LICENSE BLOCK *****
 */

/**
 * In-memory primary-key allocator.
 * Tracks the next available integer ID for each table.
 *
 * Ref: id.js:26-60  Zotero.ID_Tracker
 */
export class IdGenerator {
  /** Table name → next usable ID. */
  private nextIds: Map<string, number> = new Map();

  /** All tracked tables. Ref: id.js:27-41 */
  static readonly TABLES: string[] = [
    'collections', 'creators', 'creatorTypes', 'customFields',
    'customItemTypes', 'fields', 'itemDataValues', 'itemTypes',
    'items', 'libraries', 'proxies', 'savedSearches', 'tags',
  ];

  /**
   * Seed all tables with their current max ID from the DB.
   * Call once after DB connection is established.
   * Ref: id.js:45-49
   */
  async init(maxIdForTable: (table: string) => Promise<number>): Promise<void> {
    let tables = IdGenerator.TABLES;
    for (let i = 0; i < tables.length; i++) {
      this.nextIds.set(tables[i], (await maxIdForTable(tables[i])) + 1);
    }
  }

  /**
   * Return an unused integer ID for a table and advance the counter.
   * Ref: id.js:55-60
   */
  get(table: string): number {
    let next = this.nextIds.get(table);
    if (next === undefined) {
      throw new Error(`IDs not loaded for table '${table}' — call init() first`);
    }
    this.nextIds.set(table, next + 1);
    return next;
  }

  /**
   * Set a specific next ID (used after restoring from server).
   */
  set(table: string, nextId: number): void {
    this.nextIds.set(table, nextId);
  }

  /** Return current value without advancing. */
  peek(table: string): number {
    return this.nextIds.get(table) ?? 0;
  }

  /** Reset all counters. */
  clear(): void {
    this.nextIds.clear();
  }
}
