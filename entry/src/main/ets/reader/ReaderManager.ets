/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: xpcom/reader.js — ReaderInstance manager
 *      tabs.js — reader/note tab lifecycle
 *
 * ***** END LICENSE BLOCK *****
 */

import { ReaderState, PdfAnnotation } from './ReaderTypes.ets';

/** Callback when a reader instance state changes. */
export type ReaderStateCallback = (state: ReaderState) => void;

/**
 * Manages open reader instances (one per PDF attachment).
 *
 * Replaces: xpcom/reader.js (ReaderInstance class)
 *           + tabs.js loadable tab lifecycle
 */
export class ReaderManager {
  private instances: Map<string, ReaderState> = new Map();
  private listeners: Map<string, ReaderStateCallback[]> = new Map();

  /**
   * Open a reader for the given attachment.
   * Returns the initial state.
   */
  open(
    itemID: number,
    itemKey: string,
    title: string,
    filePath: string,
    totalPages: number = 1
  ): ReaderState {
    let state: ReaderState = {
      itemID, itemKey, title, filePath,
      totalPages, currentPage: 1,
      annotations: [], uiState: '{}',
    };
    this.instances.set(itemKey, state);
    return state;
  }

  /** Close a reader instance. */
  close(itemKey: string): boolean {
    return this.instances.delete(itemKey);
  }

  /** Get current state for a reader. */
  get(itemKey: string): ReaderState | null {
    return this.instances.get(itemKey) ?? null;
  }

  /** List all open reader keys. */
  openKeys(): string[] {
    return Array.from(this.instances.keys());
  }

  /** Open count. */
  get openCount(): number {
    return this.instances.size;
  }

  // ==================================================================
  // Page navigation
  // ==================================================================

  goToPage(itemKey: string, page: number): void {
    let s = this.instances.get(itemKey);
    if (s && page >= 1 && page <= s.totalPages) {
      s.currentPage = page;
      this._notify(itemKey, s);
    }
  }

  setTotalPages(itemKey: string, total: number): void {
    let s = this.instances.get(itemKey);
    if (s) { s.totalPages = total; this._notify(itemKey, s); }
  }

  // ==================================================================
  // Annotations
  // ==================================================================

  addAnnotation(itemKey: string, ann: PdfAnnotation): void {
    let s = this.instances.get(itemKey);
    if (s) {
      s.annotations = [...s.annotations, ann];
      this._notify(itemKey, s);
    }
  }

  setAnnotations(itemKey: string, annotations: PdfAnnotation[]): void {
    let s = this.instances.get(itemKey);
    if (s) {
      s.annotations = annotations;
      this._notify(itemKey, s);
    }
  }

  removeAnnotation(itemKey: string, annID: string): boolean {
    let s = this.instances.get(itemKey);
    if (!s) { return false; }
    let before = s.annotations.length;
    s.annotations = s.annotations.filter((a: PdfAnnotation) => a.id !== annID);
    if (s.annotations.length !== before) {
      this._notify(itemKey, s);
      return true;
    }
    return false;
  }

  updateAnnotation(itemKey: string, annID: string, patch: Partial<PdfAnnotation>): boolean {
    let s = this.instances.get(itemKey);
    if (!s) { return false; }
    let idx = s.annotations.findIndex((a: PdfAnnotation) => a.id === annID);
    if (idx < 0) { return false; }
    let orig = s.annotations[idx];
    s.annotations[idx] = {
      id: annID,
      type: patch.type ?? orig.type,
      pageIndex: patch.pageIndex ?? orig.pageIndex,
      position: patch.position ?? orig.position,
      color: patch.color ?? orig.color,
      text: patch.text ?? orig.text,
      comment: patch.comment ?? orig.comment,
      authorName: patch.authorName ?? orig.authorName,
      sortIndex: patch.sortIndex ?? orig.sortIndex,
      dateModified: patch.dateModified ?? orig.dateModified,
    };
    this._notify(itemKey, s);
    return true;
  }

  getAnnotations(itemKey: string, pageIndex: number): PdfAnnotation[] {
    let s = this.instances.get(itemKey);
    if (!s) { return []; }
    return s.annotations.filter((a: PdfAnnotation) => a.pageIndex === pageIndex);
  }

  // ==================================================================
  // Observer pattern
  // ==================================================================

  subscribe(itemKey: string, callback: ReaderStateCallback): void {
    let list = this.listeners.get(itemKey) ?? [];
    list.push(callback);
    this.listeners.set(itemKey, list);
  }

  unsubscribe(itemKey: string, callback: ReaderStateCallback): void {
    let list = this.listeners.get(itemKey);
    if (list) {
      this.listeners.set(itemKey, list.filter((cb: ReaderStateCallback) => cb !== callback));
    }
  }

  private _notify(itemKey: string, state: ReaderState): void {
    let list = this.listeners.get(itemKey);
    if (!list) { return; }
    for (let i = 0; i < list.length; i++) {
      list[i](state);
    }
  }
}

/** Global singleton. */
export const readerManager = new ReaderManager();
