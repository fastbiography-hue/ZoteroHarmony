/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: xpcom/data/search.js:976-1851  _buildQuery() — condition → SQL compiler
 *
 * ***** END LICENSE BLOCK *****
 */

/** Single creator reference for search. */
export interface SearchCreator {
  lastName: string;
  firstName: string;
}
/** Single tag reference for search. */
export interface SearchTag {
  tag: string;
}
/** Standard interface for items that can be searched. */
export interface SearchableItem {
  itemData: Map<string, string>;
  creators: SearchCreator[];
  tags: SearchTag[];
}

/** One search condition. Ref: search.js addCondition() */
export interface SearchCondition {
  id: number;
  condition: string;    // 'title', 'creator', 'tag', 'year', 'collection', etc.
  operator: string;     // 'contains', 'is', 'isNot', 'beginsWith', 'isBefore', 'isAfter'
  value: string;
  required: boolean;
}

/** Join mode. Ref: search.js:992-996 */
export type JoinMode = 'all' | 'any';

/**
 * In-memory search engine — compile conditions into filter predicates.
 *
 * This is a simplified implementation that filters ItemModel[] arrays.
 * The full SQL-compiling version (search.js _buildQuery()) requires
 * the relational store and is implemented in ZoteroDb.ets.
 *
 * Ref: search.js:976-1851  _buildQuery
 */
export class SearchEngine {
  private conditions: Map<number, SearchCondition> = new Map();
  private nextID: number = 1;
  private joinMode: JoinMode = 'all';

  // ==================================================================
  // Condition management  Ref: search.js:297-425  addCondition
  // ==================================================================

  addCondition(condition: string, operator: string, value: string, required: boolean = false): number {
    let id = this.nextID++;
    this.conditions.set(id, { id, condition, operator, value, required });
    return id;
  }

  removeCondition(id: number): boolean {
    return this.conditions.delete(id);
  }

  setJoinMode(mode: JoinMode): void { this.joinMode = mode; }

  getConditions(): SearchCondition[] {
    return Array.from(this.conditions.values());
  }

  clearConditions(): void { this.conditions.clear(); this.nextID = 1; }

  // ==================================================================
  // Filter execution  Ref: search.js:554-846  search()
  // ==================================================================

  /**
   * Apply search conditions to an array of item-like objects.
   *
   * @param items — array with shape { itemData: Map<string,string>, creators: ..., tags: ... }
   * @returns filtered array
   */
  filter<T extends SearchableItem>(items: T[]): T[] {
    let conds = this.getConditions();
    if (conds.length === 0) { return items; }

    return items.filter((item: T): boolean => {
      if (this.joinMode === 'all') {
        for (let i = 0; i < conds.length; i++) {
          if (!this._match(item, conds[i])) { return false; }
        }
        return true;
      } else {
        // ANY: at least one match
        for (let i = 0; i < conds.length; i++) {
          if (this._match(item, conds[i])) { return true; }
        }
        return false;
      }
    });
  }

  // ==================================================================
  // Single condition matcher
  // ==================================================================

  private _match<T extends SearchableItem>(item: T, cond: SearchCondition): boolean {
    let op = cond.operator;
    let val = cond.value.toLowerCase();

    switch (cond.condition) {
      case 'title':
        return this._textMatch(item.itemData.get('title') ?? '', val, op);
      case 'creator': {
        let creatorText = item.itemData.get('creator') ?? '';
        if (this._textMatch(creatorText, val, op)) { return true; }
        let creators = item.creators;
        for (let i = 0; i < creators.length; i++) {
          let full = `${creators[i].lastName} ${creators[i].firstName}`.toLowerCase();
          if (this._textMatch(full, val, op)) { return true; }
        }
        return op === 'isNot';
      }
      case 'year': {
        let date = item.itemData.get('date') ?? '';
        let year = (date.match(/(\d{4})/) ?? [''])[0];
        if (op === 'is') { return year === val; }
        if (op === 'isNot') { return year !== val; }
        if (op === 'isBefore') {
          return year !== '' && parseInt(year) < parseInt(val);
        }
        if (op === 'isAfter') {
          return year !== '' && parseInt(year) > parseInt(val);
        }
        return false;
      }
      case 'tag': {
        let tags = item.tags;
        for (let i = 0; i < tags.length; i++) {
          if (this._textMatch(tags[i].tag, val, op)) { return true; }
        }
        return op === 'isNot';
      }
      case 'DOI':
      case 'ISBN':
      case 'ISSN':
        return this._textMatch(item.itemData.get(cond.condition) ?? '', val, op);
      case 'itemType':
        return this._textMatch(item.itemData.get('itemType') ?? '', val, op);
      default:
        // Generic: check itemData
        return this._textMatch(item.itemData.get(cond.condition) ?? '', val, op);
    }
  }

  private _textMatch(text: string, search: string, op: string): boolean {
    let lower = text.toLowerCase();
    switch (op) {
      case 'contains':   return lower.includes(search);
      case 'is':         return lower === search;
      case 'isNot':      return lower !== search;
      case 'beginsWith': return lower.startsWith(search);
      default:           return lower.includes(search);
    }
  }
}
