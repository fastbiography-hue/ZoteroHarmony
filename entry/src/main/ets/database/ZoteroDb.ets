/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: xpcom/db.js — SQLite wrapper via @ohos.data.relationalStore
 *
 * ***** END LICENSE BLOCK *****
 */

import { relationalStore } from '@kit.ArkData';
import { IdGenerator } from './IdGenerator.ets';

export type Row = Record<string, string | number | null>;

export class ZoteroDb {
  private store: relationalStore.RdbStore | null = null;
  private dbPath: string;
  private txNesting: number = 0;
  idGen: IdGenerator = new IdGenerator();

  constructor(dbPath: string) { this.dbPath = dbPath; }

  async open(context: Context): Promise<void> {
    let store = await relationalStore.getRdbStore(context, {
      name: this.dbPath,
      securityLevel: relationalStore.SecurityLevel.S1,
    });
    this.store = store;
    await this.idGen.init(async (table: string): Promise<number> => {
      try {
        let result = await this.store!.querySql(`SELECT MAX(rowid) FROM ${table}`);
        if (result.goToNextRow()) {
          let v = result.getLong(0);
          result.close();
          return v;
        }
        result.close();
        return 0;
      } catch (_e) { return 0; }
    });
  }

  async close(): Promise<void> {
    if (this.store) { await this.store.close(); this.store = null; }
  }

  get isOpen(): boolean { return this.store !== null; }
  get isInTransaction(): boolean { return this.txNesting > 0; }

  async queryAsync(sql: string, params: (string | number | null)[] = []): Promise<Row[]> {
    this._requireStore();
    let rows: Row[] = [];
    let result = await this.store!.querySql(sql, this._toBindings(params));
    while (result.goToNextRow()) { rows.push(this._rowToObject(result)); }
    result.close();
    return rows;
  }

  async columnQueryAsync(sql: string, params: (string | number | null)[] = []): Promise<(string | number | null)[]> {
    let rows = await this.queryAsync(sql, params);
    if (rows.length === 0) { return []; }
    let k = Object.keys(rows[0])[0];
    let result: (string | number | null)[] = [];
    for (let i = 0; i < rows.length; i++) { result.push(rows[i][k]); }
    return result;
  }

  async valueQueryAsync(sql: string, params: (string | number | null)[] = []): Promise<string | number | null> {
    let rows = await this.queryAsync(sql, params);
    if (rows.length === 0) { return null; }
    return rows[0][Object.keys(rows[0])[0]];
  }

  async executeSql(sql: string, params: (string | number | null)[] = []): Promise<void> {
    this._requireStore();
    await this.store!.executeSql(sql, this._toBindings(params));
  }

  async executeTransaction<T>(fn: () => Promise<T>): Promise<T> {
    this._requireStore();
    let isOuter = this.txNesting === 0;
    this.txNesting++;
    if (isOuter) { this.store!.beginTransaction(); }
    try {
      let result = await fn();
      if (isOuter) { this.store!.commit(); }
      return result;
    } catch (e) {
      if (isOuter) { this.store!.rollBack(); }
      let err = e as Error;
      throw err;
    } finally { this.txNesting--; }
  }

  async tableExists(name: string): Promise<boolean> {
    try {
      let rows = await this.queryAsync(
        `SELECT name FROM sqlite_master WHERE type='table' AND name=?`, [name]
      );
      return rows.length > 0;
    } catch (_e) { return false; }
  }

  async getColumns(table: string): Promise<string[]> {
    let rows = await this.queryAsync(`PRAGMA table_info(${table})`);
    let result: string[] = [];
    for (let i = 0; i < rows.length; i++) { result.push(rows[i]['name'] as string); }
    return result;
  }

  private _requireStore(): void {
    if (!this.store) { throw new Error('Database not opened'); }
  }

  private _toBindings(params: (string | number | null)[]): string[] {
    let result: string[] = [];
    let count = params.length;
    for (let i = 0; i < count; i++) {
      let v = params[i];
      result.push(v === null || v === undefined ? '' : `${v}`);
    }
    return result;
  }

  private _rowToObject(result: relationalStore.ResultSet): Row {
    let obj: Row = {};
    let colCount = result.columnCount;
    for (let i = 0; i < colCount; i++) {
      let name = result.columnNames[i];
      // Use string value + null check instead of type enum
      let strVal: string | null = null;
      try { strVal = result.getString(i); } catch (_e) { /*not string*/ }
      let numVal: number | null = null;
      try { numVal = result.getLong(i); } catch (_e2) { /*not long*/ }
      let dblVal: number | null = null;
      try { dblVal = result.getDouble(i); } catch (_e3) { /*not double*/ }

      if (strVal !== null) {
        obj[name] = strVal;
      } else if (dblVal !== null) {
        obj[name] = dblVal;
      } else if (numVal !== null) {
        obj[name] = numVal;
      } else {
        obj[name] = null;
      }
    }
    return obj;
  }
}
