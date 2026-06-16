/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ported from Zotero Desktop (AGPL-3.0)
 * Original: chrome/content/zotero/xpcom/data/collection.js
 *
 * ***** END LICENSE BLOCK *****
 */

import { DataObject, DataObjectJSON, JSONMode } from './DataObject.ets';

/**
 * API JSON for Collection.
 * Ref: collection.js:809-822 (toJSON)
 */
export interface CollectionJSON extends DataObjectJSON {
  name: string;
  parentCollection: string | boolean;
  relations: Record<string, string[]>;
}

/**
 * Collection (folder) entity.
 *
 * Fields (ref: collection.js:26-34):
 *   _name              — display name
 *   _childCollections  — Set of child collection IDs
 *   _childItems        — Set of child item IDs
 *
 * Ref: collection.js:37  extends DataObject
 * Ref: collection.js:39  _objectType = 'collection'
 */
export class CollectionModel extends DataObject {
  // ---- Core fields (ref: collection.js:29-32) ----
  private _name: string | null = null;
  private _childCollections: Set<number> = new Set();
  private _childItems: Set<number> = new Set();

  protected _objectType = 'collection';

  // ==================================================================
  // Public getters / setters (ref: collection.js:50-69)
  // ==================================================================

  get name(): string | null {
    return this._name;
  }

  set name(value: string | null) {
    this._name = value;
  }

  get childCollections(): Set<number> {
    return this._childCollections;
  }

  get childItems(): Set<number> {
    return this._childItems;
  }

  // ==================================================================
  // Convenience (ref: collection.js:176-190)
  // ==================================================================

  hasChildCollections(): boolean {
    return this._childCollections.size > 0;
  }

  hasChildItems(): boolean {
    return this._childItems.size > 0;
  }

  /**
   * Add child item ID.
   * Ref: collection.js  addItem()
   */
  addChildItem(itemID: number): void {
    this._childItems.add(itemID);
  }

  /**
   * Remove child item ID.
   */
  removeChildItem(itemID: number): boolean {
    return this._childItems.delete(itemID);
  }

  // ==================================================================
  // toJSON — Zotero Web API v3 (ref: collection.js:809-822)
  // ==================================================================

  toJSON(mode: JSONMode = 'new'): CollectionJSON {
    let obj: CollectionJSON = {
      key: this.key,
      version: this.version,
      name: this._name ?? '',
      parentCollection: this.parentKey ?? false,
      relations: this.getRelations(),
    };
    return obj;
  }

  /**
   * Populate from API JSON.
   * Ref: collection.js:775-806
   */
  fromJSON(json: Record<string, Object>): void {
    if (json['name'] !== undefined) {
      this._name = json['name'] as string;
    }
    if (json['parentCollection'] !== undefined) {
      let pc = json['parentCollection'];
      this.parentKey = pc ? (pc as string) : null;
    }
    if (json['relations'] !== undefined) {
      this.setRelations(json['relations'] as Record<string, string[]>);
    }
    if (json['deleted'] !== undefined) {
      // deleted inherited from DataObject base
    }
  }
}
