/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: collectionTree.jsx — hierarchical collection tree (React → ArkUI)
 *
 * ***** END LICENSE BLOCK *****
 */

import {
  CollectionTreeRow, CollectionRowType, rowIcon, buildDefaultRows,
} from './CollectionTreeRow.ets';
import { AppStore } from '../../utils/AppStore.ets';
import { ZHColor, ZHMetric } from '../../theme/ThemeConstants.ets';
import { LibraryRepository } from '../../database/LibraryRepository.ets';

/**
 * Single row in the collection tree.
 * Indented by level * indentWidth.
 */
@Component
struct CollectionRowItem {
  @Prop row: CollectionTreeRow = { id: '', type: 'collection', name: '', level: 0, isOpen: false, hasChildren: false, libraryID: 0 };
  @Prop selectedRowID: string = '';
  @StorageLink('zotero_theme') themeMode: string = 'light';
  onSelect?: (row: CollectionTreeRow) => void;
  onToggle?: (row: CollectionTreeRow) => void;
  onAction?: (action: string, row: CollectionTreeRow) => void;

  build() {
    Row() {
      // Indent
      Blank().width(this.row.level * 18)

      // Toggle arrow (only if has children)
      if (this.row.hasChildren) {
        Text(this.row.isOpen ? '▾' : '▸')
          .fontSize(12).fontColor(this.row.id === this.selectedRowID ? ZHColor.TEXT_INVERSE : (this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_SUBTLE)).width(16)
          .onClick(() => { if (this.onToggle) { this.onToggle(this.row); } })
      } else {
        Blank().width(16)
      }

      // Icon
      Text(rowIcon(this.row.type, this.row.isOpen))
        .fontSize(14)
        .fontColor(this.row.id === this.selectedRowID ? ZHColor.TEXT_INVERSE : (this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED))
        .margin({ right: 7 })

      // Name
      Text(this.row.name)
        .fontSize(14)
        .fontColor(this.row.id === this.selectedRowID ? ZHColor.TEXT_INVERSE : (this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT))
        .fontWeight(this.row.id === this.selectedRowID ? FontWeight.Medium : FontWeight.Normal)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.row.type === 'collection' || this.row.type === 'search') {
        Button('⋯')
          .fontSize(16)
          .width(28)
          .height(28)
          .backgroundColor('#00000000')
          .fontColor(this.row.id === this.selectedRowID ? ZHColor.TEXT_INVERSE : (this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED))
          .bindMenu(this._rowMenu)
      }
    }
    .width('100%')
    .height(ZHMetric.ROW_HEIGHT)
    .padding({ left: 10, right: 8 })
    .backgroundColor(this.row.id === this.selectedRowID ? ZHColor.BRAND : ZHColor.TRANSPARENT)
    .borderRadius(ZHMetric.RADIUS_SMALL)
    .margin({ left: 6, right: 6, top: 1, bottom: 1 })
    .onClick(() => { if (this.onSelect) { this.onSelect(this.row); } })
  }

  @Builder
  _rowMenu() {
    Column() {
      Button('Rename').fontSize(13).height(34).width('100%')
        .onClick(() => { if (this.onAction) { this.onAction('rename', this.row); } })
      if (this.row.type === 'collection') {
        Button('New child collection').fontSize(13).height(34).width('100%')
          .onClick(() => { if (this.onAction) { this.onAction('new-child', this.row); } })
        Button('Delete').fontSize(13).height(34).width('100%')
          .onClick(() => { if (this.onAction) { this.onAction('delete', this.row); } })
      } else if (this.row.type === 'search') {
        Button('Delete').fontSize(13).height(34).width('100%')
          .onClick(() => { if (this.onAction) { this.onAction('delete', this.row); } })
      }
    }
    .padding(6)
    .backgroundColor('#FFFFFF')
  }
}

/**
 * Hierarchical collection tree.
 *
 * Replaces: collectionTree.jsx (React VirtualizedTree → ArkUI List)
 * Shows: My Library → collections → subcollections → searches → system views
 */
@Component
export struct CollectionTree {
  @Link selectedRowID: string;
  @Watch('reload')
  @Prop revision: number = 0;
  @StorageLink('zotero_theme') themeMode: string = 'light';
  @State allRows: CollectionTreeRow[] = [];
  @State rows: CollectionTreeRow[] = [];
  onRowSelected?: (row: CollectionTreeRow) => void;
  onRowAction?: (action: string, row: CollectionTreeRow) => void;

  aboutToAppear(): void {
    this.reload();
  }

  build() {
    List() {
      ForEach(this.rows, (row: CollectionTreeRow) => {
        ListItem() {
          CollectionRowItem({
            row: row,
            selectedRowID: this.selectedRowID,
            themeMode: this.themeMode,
            onSelect: (r: CollectionTreeRow) => {
              this.selectedRowID = r.id;
              if (r.libraryID) {
                AppStore.selectedLibraryID = r.libraryID;
              }
              if (r.key) {
                AppStore.selectedCollectionKey = r.key;
              }
              if (this.onRowSelected) { this.onRowSelected(r); }
            },
            onToggle: (r: CollectionTreeRow) => {
              this._toggleOpen(r);
            },
            onAction: (action: string, r: CollectionTreeRow) => {
              if (this.onRowAction) { this.onRowAction(action, r); }
            },
          })
        }
        .width('100%')
      }, (row: CollectionTreeRow): string => row.id)
    }
    .width('100%')
    .padding({ top: 4, bottom: 8 })
    .backgroundColor(this.themeMode === 'dark' ? '#171B22' : ZHColor.TRANSPARENT)
  }

  /** Toggle open/closed and show/hide children at deeper level. */
  private _toggleOpen(row: CollectionTreeRow): void {
    let update: CollectionTreeRow[] = [];
    for (let i = 0; i < this.allRows.length; i++) {
      let r = this.allRows[i];
      if (r.id === row.id) {
        update.push({
          id: r.id, type: r.type, name: r.name,
          level: r.level, isOpen: !r.isOpen,
          hasChildren: r.hasChildren, libraryID: r.libraryID, key: r.key,
          parentRowID: r.parentRowID,
        });
      } else {
        update.push(r);
      }
    }
    this.allRows = update;
    this.rows = this._visibleRows(update);
  }

  /** Reload from local DB-backed library repository. */
  reload(): void {
    let context = getContext(this).getApplicationContext();
    let repo = new LibraryRepository();
    repo.open(context).then(() => {
      return repo.listCollectionRows();
    }).then((loadedRows: CollectionTreeRow[]) => {
      this.allRows = loadedRows;
      this.rows = this._visibleRows(loadedRows);
      repo.close();
    }).catch((_err: Error) => {
      this.allRows = buildDefaultRows();
      this.rows = buildDefaultRows();
      repo.close();
    });
  }

  private _visibleRows(source: CollectionTreeRow[]): CollectionTreeRow[] {
    let visible: CollectionTreeRow[] = [];
    for (let i = 0; i < source.length; i++) {
      let row = source[i];
      if (this._isRowVisible(row, source)) {
        visible.push(row);
      }
    }
    return visible;
  }

  private _isRowVisible(row: CollectionTreeRow, source: CollectionTreeRow[]): boolean {
    if (!row.parentRowID) {
      return true;
    }
    let parent = this._findRow(row.parentRowID, source);
    if (!parent || !parent.isOpen) {
      return false;
    }
    return this._isRowVisible(parent, source);
  }

  private _findRow(rowID: string, source: CollectionTreeRow[]): CollectionTreeRow | null {
    for (let i = 0; i < source.length; i++) {
      if (source[i].id === rowID) {
        return source[i];
      }
    }
    return null;
  }
}
