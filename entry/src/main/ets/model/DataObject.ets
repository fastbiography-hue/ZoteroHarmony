/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ported from Zotero Desktop (AGPL-3.0)
 * Original: chrome/content/zotero/xpcom/data/dataObject.js
 *
 * ***** END LICENSE BLOCK *****
 */

import { RelationTupleArray, RelationUtils } from './Relations.ets';

/** JSON mode for serialization.  Ref: dataObject.js:1412 */
export type JSONMode = 'full' | 'new' | 'diff' | 'patch' | 'download';

/** Minimal API JSON shape.  Ref: dataObject.js:1410-1443 */
export interface DataObjectJSON {
  key: string | null;
  version: number | null;
  deleted?: boolean;
}

/**
 * Abstract base for all Zotero data entities.
 *
 * Fields (ref: dataObject.js:47-69):
 *   _id, _libraryID, _key         — primary identifiers
 *   _version, _synced             — sync state
 *   _dateAdded, _dateModified    — SQL date stamps
 *   _deleted                      — soft-delete flag
 *   _parentID, _parentKey        — parent linkage
 *   _relations                    — RDF predicate→object tuples
 */
export abstract class DataObject {
  // ---- Primary identifiers (ref: dataObject.js:47-49) ----
  private _id: number | null = null;
  private _libraryID: number | null = null;
  private _key: string | null = null;
  // ---- Sync fields (ref: dataObject.js:50-53) ----
  private _version: number | null = null;
  private _synced: boolean | null = null;
  private _dateAdded: string | null = null;
  private _dateModified: string | null = null;
  // ---- Identity (ref: dataObject.js:54) ----
  private _identified: boolean = false;
  // ---- Parent (ref: dataObject.js:55-57) ----
  private _parentID: number | null = null;
  private _parentKey: string | null = null;
  private _deleted: boolean | null = null;
  // ---- Relations (ref: dataObject.js:59) ----
  protected _relations: RelationTupleArray = [];
  // ---- Type marker (ref: dataObject.js:71) ----
  protected _objectType: string = 'dataObject';

  // ============ Getters (ref: dataObject.js:74-98) ============

  get objectType(): string    { return this._objectType; }
  get id():          number | null { return this._id; }
  set id(value: number | null) { this._id = value; }
  get libraryID():   number | null { return this._libraryID; }
  set libraryID(value: number | null) { this._libraryID = value; }
  get key():         string | null { return this._key; }
  set key(value: string | null) { this._key = value; }

  get libraryKey(): string {
    if (this._libraryID === null || this._key === null) { return ''; }
    return `${this._libraryID}/${this._key}`;  // ref: dataObject.js:91-93
  }

  get version():       number | null   { return this._version; }
  set version(value: number | null) { this._version = value; }
  get synced():        boolean | null  { return this._synced; }
  set synced(value: boolean | null) { this._synced = value; }
  get deleted():       boolean | null  { return this._deleted; }
  set deleted(value: boolean | null) { this._deleted = value; }
  get dateAdded():     string | null   { return this._dateAdded; }
  set dateAdded(value: string | null) { this._dateAdded = value; }
  get dateModified():  string | null   { return this._dateModified; }
  set dateModified(value: string | null) { this._dateModified = value; }
  get parentID():      number | null   { return this._parentID; }    // ref:256-267
  set parentID(value: number | null) { this._parentID = value; }
  get parentKey():     string | null   { return this._parentKey; }    // ref:285-290
  set parentKey(value: string | null) { this._parentKey = value; }
  get identified():    boolean         { return this._identified; }
  set identified(value: boolean) { this._identified = value; }

  // ============ Relations (delegate to RelationUtils) ============
  // Ref: dataObject.js:323-488

  getRelations(): Record<string, string[]> {
    return RelationUtils.toRecord(this._relations);
  }
  getRelationsByPredicate(predicate: string): string[] {
    return RelationUtils.getByPredicate(this._relations, predicate);
  }
  addRelation(predicate: string, object: string): boolean {
    return RelationUtils.add(this._relations, predicate, object);
  }
  hasRelation(predicate: string, object: string): boolean {
    return RelationUtils.has(this._relations, predicate, object);
  }
  removeRelation(predicate: string, object: string): boolean {
    return RelationUtils.remove(this._relations, predicate, object);
  }
  setRelations(newRelations: Record<string, string[]>): boolean {
    RelationUtils.setFromRecord(this._relations, newRelations);
    return true;
  }

  // ============ Serialization (abstract) ============
  // Ref: item.js:5725 toJSON / item.js:5373 fromJSON

  abstract toJSON(mode?: JSONMode): DataObjectJSON;
  abstract fromJSON(json: Record<string, Object>): void;

  // ============ Utilities (ref: dataObject.js:1450-1452) ============

  static generateKey(): string {
    const CHARS = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    const LEN = 8; let result = '';
    for (let i = 0; i < LEN; i++) {
      result += CHARS.charAt(Math.floor(Math.random() * CHARS.length));
    }
    return result;
  }
}
