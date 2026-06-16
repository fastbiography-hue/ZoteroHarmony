/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: itemTree.jsx — multi-column virtualized item list (React → ArkUI)
 *
 * ***** END LICENSE BLOCK *****
 */

import { ItemModel } from '../../model/ItemModel.ets';
import { ItemTreeColumn, DEFAULT_COLUMNS } from '../table/ItemTreeColumns.ets';
import { AppStore } from '../../utils/AppStore.ets';
import { Preferences, PrefKey } from '../../utils/Preferences.ets';
import { ZHColor, ZHMetric } from '../../theme/ThemeConstants.ets';
import { LibraryRepository, ItemChildSummary } from '../../database/LibraryRepository.ets';
import { SearchEngine } from '../../search/SearchEngine.ets';
import { ItemTreeToolbar } from '../ItemTreeToolbar.ets';
import {
  buildItemTreeRows,
  applyPendingSyncToRows,
  collectParentKeysForChildLookup,
} from '../helpers/ItemTreeRowHelpers.ets';

export {
  buildItemTreeRows,
  applyPendingSyncToRows,
  collectParentKeysForChildLookup,
};

/** Flattened tree row view-model for ForEach rendering. */
export interface ItemTreeRowModel {
  id: string;
  key: string;
  rowType: 'item' | 'attachment' | 'note' | 'annotation';
  level: number;
  item: ItemModel | null;
  parentKey: string;
  title: string;
  subtitle: string;
  icon: string;
  isExpandable: boolean;
  isExpanded: boolean;
  childCount: number;
  isPendingSync: boolean;
}

function _iconForItemType(itemType: string): string {
  let lower = itemType.toLowerCase();
  if (lower === 'book') { return 'B'; }
  if (lower === 'conferencepaper') { return 'C'; }
  if (lower === 'thesis') { return 'T'; }
  if (lower === 'report') { return 'R'; }
  if (lower === 'note') { return 'N'; }
  if (lower === 'attachment') { return 'A'; }
  if (lower === 'annotation') { return 'H'; }
  return 'J';
}

/** One item row in the tree. */
@Component
struct ItemRow {
  @Prop item: ItemModel;
  @Prop columns: ItemTreeColumn[] = [];
  @Prop isSelected: boolean = false;
  @Prop isChecked: boolean = false;
  @Prop themeMode: string = 'light';
  @Prop viewMode: string = 'collection';
  @Prop showMenu: boolean = true;
  onTap?: (item: ItemModel) => void;
  onCheck?: (item: ItemModel, checked: boolean) => void;
  onDoubleTap?: (item: ItemModel) => void;
  onMenuAction?: (action: string, item: ItemModel) => void;

  build() {
    Row() {
      Checkbox({ name: `select-${this.item.id ?? 0}` })
        .select(this.isChecked)
        .width(24)
        .height(24)
        .margin({ right: 6 })
        .onChange((checked: boolean) => {
          if (this.onCheck) { this.onCheck(this.item, checked); }
        })

      ForEach(this.columns, (col: ItemTreeColumn, idx: number) => {
        // Primary column gets more space
        if (col.primary) {
          // Icon + title
          Row() {
            Text((this.item.itemData.get('itemType') ?? 'journalArticle') === 'book' ? 'B' :
              ((this.item.itemData.get('itemType') ?? 'journalArticle') === 'conferencePaper' ? 'C' :
                ((this.item.itemData.get('itemType') ?? 'journalArticle') === 'note' ? 'N' :
                  ((this.item.itemData.get('itemType') ?? 'journalArticle') === 'attachment' ? 'A' :
                    ((this.item.itemData.get('itemType') ?? 'journalArticle') === 'report' ? 'R' : 'J')))))
              .fontSize(10)
              .fontColor(this.isSelected ? ZHColor.TEXT_INVERSE : ZHColor.BRAND)
              .fontWeight(FontWeight.Bold)
              .width(22)
              .height(22)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.isSelected ? ZHColor.BRAND_DARK : ZHColor.BRAND_SOFT)
              .borderRadius(5)
              .margin({ right: 8 })
            Text(col.render(this.item))
              .fontSize(14)
              .fontColor(this.isSelected ? ZHColor.TEXT : (this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT))
              .fontWeight(FontWeight.Medium)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(col.flex)
        } else {
          Text(col.render(this.item))
            .fontSize(13)
            .fontColor(this.isSelected ? ZHColor.TEXT : (this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(col.flex)
            .padding({ left: idx === 0 ? 0 : 8 })
        }
      }, (col: ItemTreeColumn, index: number): string => `${col.dataKey}-${index}`)

      if (this.showMenu) {
        Button('⋯')
          .fontSize(16)
          .width(30)
          .height(30)
          .backgroundColor('#00000000')
          .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
          .bindMenu(this._rowMenu)
      }
    }
    .width('100%')
    .height(ZHMetric.ROW_HEIGHT)
    .padding({ left: 10, right: 10 })
    .backgroundColor(this.isSelected ? ZHColor.SELECTED : (this.themeMode === 'dark' ? '#11151B' : ZHColor.SURFACE))
    .border({ width: { bottom: 0.5 }, color: this.themeMode === 'dark' ? '#252C38' : ZHColor.BORDER_SOFT })
    .onClick(() => { if (this.onTap) { this.onTap(this.item); } })
  }

  @Builder
  _rowMenu() {
    Column() {
      Button('Open').fontSize(13).height(36).width('100%')
        .onClick(() => { if (this.onMenuAction) { this.onMenuAction('open', this.item); } })
      Button('Copy citation').fontSize(13).height(36).width('100%')
        .onClick(() => { if (this.onMenuAction) { this.onMenuAction('citation', this.item); } })
      Button('Copy bibliography').fontSize(13).height(36).width('100%')
        .onClick(() => { if (this.onMenuAction) { this.onMenuAction('bibliography', this.item); } })
      Button('Add note').fontSize(13).height(36).width('100%')
        .onClick(() => { if (this.onMenuAction) { this.onMenuAction('note', this.item); } })
      Button('Add attachment').fontSize(13).height(36).width('100%')
        .onClick(() => { if (this.onMenuAction) { this.onMenuAction('attachment', this.item); } })
      if (this.viewMode !== 'trash') {
        Button('Add to collection').fontSize(13).height(36).width('100%')
          .onClick(() => { if (this.onMenuAction) { this.onMenuAction('addToCollection', this.item); } })
      }
      if (this.viewMode === 'trash') {
        Button('Restore').fontSize(13).height(36).width('100%')
          .onClick(() => { if (this.onMenuAction) { this.onMenuAction('restore', this.item); } })
      } else {
        Button('Delete').fontSize(13).height(36).width('100%')
          .onClick(() => { if (this.onMenuAction) { this.onMenuAction('delete', this.item); } })
      }
    }
    .padding(6)
    .backgroundColor('#FFFFFF')
  }

}

/**
 * Tree row — renders a single ItemTreeRowModel with level indentation
 * and expand/collapse button for expandable parent rows.
 */
@Component
struct TreeRow {
  @Prop row: ItemTreeRowModel;
  @Prop columns: ItemTreeColumn[] = [];
  @Prop isSelected: boolean = false;
  @Prop isChecked: boolean = false;
  @Prop themeMode: string = 'light';
  @Prop viewMode: string = 'collection';
  @Prop showMenu: boolean = true;
  onTap?: (row: ItemTreeRowModel) => void;
  onCheck?: (row: ItemTreeRowModel, checked: boolean) => void;
  onExpand?: (row: ItemTreeRowModel) => void;
  onMenuAction?: (action: string, row: ItemTreeRowModel) => void;

  build() {
    Row() {
      // Level indentation
      if (this.row.level === 1) {
        Blank().width(24);
      }
      // Expand/collapse control for parent rows
      if (this.row.isExpandable) {
        Text(this.row.isExpanded ? '▼' : '▶')
          .fontSize(10)
          .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
          .width(16).textAlign(TextAlign.Center)
          .margin({ right: 2 })
          .onClick(() => { if (this.onExpand) { this.onExpand(this.row); } })
      } else if (this.row.level === 1) {
        // Narrow spacer for child rows without expand button
        Blank().width(18);
      }

      Checkbox({ name: `select-${this.row.id}` })
        .select(this.isChecked)
        .width(24).height(24)
        .margin({ right: 6 })
        .onChange((checked: boolean) => {
          if (this.onCheck) { this.onCheck(this.row, checked); }
        })

      ForEach(this.columns, (col: ItemTreeColumn, idx: number) => {
        if (col.primary) {
          Row() {
            Text(this.row.rowType === 'item' && this.row.item
              ? _iconForItemType(this.row.item.itemData.get('itemType') ?? 'journalArticle')
              : this.row.icon)
              .fontSize(10)
              .fontColor(this.isSelected ? ZHColor.TEXT_INVERSE : ZHColor.BRAND)
              .fontWeight(FontWeight.Bold)
              .width(22).height(22)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.isSelected ? ZHColor.BRAND_DARK : ZHColor.BRAND_SOFT)
              .borderRadius(5)
              .margin({ right: 8 })
            Column() {
              Row() {
                if (this.row.isPendingSync) {
                  Text('●')
                    .fontSize(8).fontColor('#E65100')
                    .margin({ right: 4 })
                }
                Text(this.row.title)
                  .fontSize(14)
                  .fontColor(this.isSelected ? ZHColor.TEXT :
                    (this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT))
                  .fontWeight(this.row.rowType === 'item' ? FontWeight.Medium : FontWeight.Normal)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
              }
              .width('100%')
              if (this.row.subtitle.length > 0) {
                Text(this.row.subtitle)
                  .fontSize(11)
                  .fontColor(this.themeMode === 'dark' ? '#677388' : ZHColor.TEXT_SUBTLE)
                  .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
          }
          .layoutWeight(col.flex)
        } else if (this.row.rowType === 'item' && this.row.item) {
          Text(col.render(this.row.item))
            .fontSize(13)
            .fontColor(this.isSelected ? ZHColor.TEXT :
              (this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(col.flex)
            .padding({ left: idx === 0 ? 0 : 8 })
        } else {
          // Child rows: only primary column shows content
          Blank().layoutWeight(col.flex)
        }
      }, (col: ItemTreeColumn, idx: number): string => `${col.dataKey}-${idx}`)

      if (this.showMenu && this.row.rowType === 'item') {
        Button('⋯')
          .fontSize(16).width(30).height(30)
          .backgroundColor('#00000000')
          .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
          .bindMenu(this._parentMenu)
      } else if (this.showMenu && this.row.rowType !== 'item') {
        Button('⋯')
          .fontSize(16).width(30).height(30)
          .backgroundColor('#00000000')
          .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
          .bindMenu(this._childMenu)
      }
    }
    .width('100%').height(ZHMetric.ROW_HEIGHT)
    .padding({ left: 10 + (this.row.level * 20), right: 10 })
    .backgroundColor(this.isSelected ? ZHColor.SELECTED :
      (this.themeMode === 'dark' ? '#11151B' : ZHColor.SURFACE))
    .border({ width: { bottom: 0.5 },
      color: this.themeMode === 'dark' ? '#252C38' : ZHColor.BORDER_SOFT })
    .onClick(() => { if (this.onTap) { this.onTap(this.row); } })
  }

  @Builder
  _parentMenu() {
    Column() {
      Button('Open').fontSize(13).height(36).width('100%')
        .onClick(() => { if (this.onMenuAction) { this.onMenuAction('open', this.row); } })
      Button('Copy citation').fontSize(13).height(36).width('100%')
        .onClick(() => { if (this.onMenuAction) { this.onMenuAction('citation', this.row); } })
      Button('Copy bibliography').fontSize(13).height(36).width('100%')
        .onClick(() => { if (this.onMenuAction) { this.onMenuAction('bibliography', this.row); } })
      Button('Add note').fontSize(13).height(36).width('100%')
        .onClick(() => { if (this.onMenuAction) { this.onMenuAction('note', this.row); } })
      Button('Add attachment').fontSize(13).height(36).width('100%')
        .onClick(() => { if (this.onMenuAction) { this.onMenuAction('attachment', this.row); } })
      if (this.viewMode !== 'trash') {
        Button('Add to collection').fontSize(13).height(36).width('100%')
          .onClick(() => { if (this.onMenuAction) { this.onMenuAction('addToCollection', this.row); } })
      }
      Button(this.viewMode === 'trash' ? 'Restore' : 'Delete').fontSize(13).height(36).width('100%')
        .onClick(() => {
          if (this.onMenuAction) {
            this.onMenuAction(this.viewMode === 'trash' ? 'restore' : 'delete', this.row);
          }
        })
    }
    .padding(6).backgroundColor('#FFFFFF')
  }

  @Builder
  _childMenu() {
    Column() {
      if (this.row.rowType === 'attachment') {
        Button('Open').fontSize(13).height(36).width('100%')
          .onClick(() => { if (this.onMenuAction) { this.onMenuAction('openAttachment', this.row); } })
      }
      if (this.row.rowType === 'note') {
        Button('Edit').fontSize(13).height(36).width('100%')
          .onClick(() => { if (this.onMenuAction) { this.onMenuAction('editNote', this.row); } })
      }
      if (this.row.rowType === 'annotation') {
        Button('Open in reader').fontSize(13).height(36).width('100%')
          .onClick(() => { if (this.onMenuAction) { this.onMenuAction('openAnnotation', this.row); } })
      }
      Button('Delete').fontSize(13).height(36).width('100%')
        .onClick(() => { if (this.onMenuAction) { this.onMenuAction('deleteChild', this.row); } })
    }
    .padding(6).backgroundColor('#FFFFFF')
  }
}

/**
 * Virtualized item list with multi-column layout + parent/child hierarchy.
 *
 * Replaces: itemTree.jsx (React VirtualizedTree → ArkUI List + LazyForEach)
 */
@Component
export struct ItemTree {
  @Link selectedItemKey: string;
  @Link selectedItemKeys: string[];
  @Watch('reload')
  @Prop collectionKey: string = '';
  @Watch('reload')
  @Prop filterText: string = '';
  @Watch('reload')
  @Prop revision: number = 0;
  @Watch('reload')
  @Prop viewMode: string = 'collection';
  @Prop showToolbar: boolean = true;
  @Prop showHeaders: boolean = true;
  @Prop showRowMenu: boolean = true;
  @Prop excludeItemKeys: string[] = [];
  @State items: ItemModel[] = [];
  @State rows: ItemTreeRowModel[] = [];
  @State expandedKeys: string[] = [];
  @State columns: ItemTreeColumn[] = DEFAULT_COLUMNS;
  @State sortKey: string = 'title';
  @State sortAsc: boolean = true;
  @StorageLink('zotero_theme') themeMode: string = 'light';
  /** Pending sync key map — applied to rows after rebuild. */
  @Prop pendingSyncMap: Record<string, boolean> = {};
  /** Drives re-application of pending flags without DB re-query. */
  @Watch('_onPendingSyncChanged')
  @Prop pendingSyncRevision: number = 0;
  onItemSelected?: (item: ItemModel) => void;
  onItemAction?: (action: string, item: ItemModel) => void;

  aboutToAppear(): void {
    this._loadDisplayPreferences().then(() => {
      this.reload();
    }).catch((_err: Error) => {
      this.reload();
    });
  }

  build() {
    Column() {
      if (this.showToolbar) {
        ItemTreeToolbar({
          columns: this.columns,
          sortKey: this.sortKey,
          sortAsc: this.sortAsc,
          onToggleColumn: (dataKey: string) => {
            this._toggleColumn(dataKey);
          },
          onResetColumns: () => {
            this._resetColumns();
          },
          onSortChange: (key: string, asc: boolean) => {
            this._setSort(key, asc);
          },
        })
      }

      if (this.showHeaders) {
        Row() {
          ForEach(this.columns, (col: ItemTreeColumn) => {
            Row() {
              Text(col.label)
                .fontSize(11).fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
                .fontWeight(FontWeight.Bold)
                .textCase(TextCase.UpperCase)
              if (col.sortable && this.sortKey === col.dataKey) {
                Text(this.sortAsc ? ' ▲' : ' ▼').fontSize(10).fontColor(ZHColor.BRAND)
              }
            }
            .layoutWeight(col.flex)
            .padding({ left: col.primary ? 8 : 4, right: 4 })
            .onClick(() => {
              if (!col.sortable) { return; }
              if (this.sortKey === col.dataKey) {
                this._setSort(col.dataKey, !this.sortAsc);
              } else {
                this._setSort(col.dataKey, true);
              }
            })
          }, (col: ItemTreeColumn): string => col.dataKey)
        }
        .width('100%').height(ZHMetric.HEADER_HEIGHT)
        .backgroundColor(this.themeMode === 'dark' ? '#1B2028' : ZHColor.SURFACE_ALT)
        .border({ width: { bottom: 1 }, color: this.themeMode === 'dark' ? '#303846' : ZHColor.BORDER })
        .padding({ left: 8 })
      }

      // Tree rows
      List() {
        ForEach(this.rows, (row: ItemTreeRowModel) => {
          // filterText already applied to parent items; child rows display
          // only when parent is expanded (no separate child filtering)
          ListItem() {
            TreeRow({
              row: row,
              columns: this.columns,
              isSelected: this.selectedItemKey === row.key,
              isChecked: this.selectedItemKeys.indexOf(row.key) >= 0,
              themeMode: this.themeMode,
              viewMode: this.viewMode,
              showMenu: this.showRowMenu,
              onTap: (r: ItemTreeRowModel) => {
                this.selectedItemKey = r.key;
                this.selectedItemKeys = [r.key];
                AppStore.selectedItemKey = r.key;
                if (r.item && this.onItemSelected) {
                  this.onItemSelected(r.item);
                } else if (this.onItemSelected) {
                  this._loadItemForRow(r).then((loadedItem: ItemModel | null) => {
                    if (loadedItem && this.onItemSelected) {
                      this.onItemSelected(loadedItem);
                    }
                  }).catch((_err: Error) => {});
                }
              },
              onCheck: (r: ItemTreeRowModel, checked: boolean) => {
                if (checked) {
                  if (this.selectedItemKeys.indexOf(r.key) < 0) {
                    this.selectedItemKeys = [...this.selectedItemKeys, r.key];
                  }
                } else {
                  this.selectedItemKeys = this.selectedItemKeys.filter((k: string) => k !== r.key);
                }
                this.selectedItemKey = this.selectedItemKeys.length > 0
                  ? this.selectedItemKeys[this.selectedItemKeys.length - 1] : '';
                AppStore.selectedItemKey = this.selectedItemKey;
                if (r.item && this.onItemSelected) {
                  this.onItemSelected(r.item);
                }
              },
              onExpand: (r: ItemTreeRowModel) => {
                this._toggleExpand(r.key);
              },
              onMenuAction: (action: string, r: ItemTreeRowModel) => {
                this.selectedItemKey = r.key;
                this.selectedItemKeys = [r.key];
                AppStore.selectedItemKey = r.key;
                if (r.item && this.onItemAction) {
                  this.onItemAction(action, r.item);
                } else if (this.onItemAction) {
                  // Lazy-load the real ItemModel for child rows
                  this._loadItemForRow(r).then((loadedItem: ItemModel | null) => {
                    if (loadedItem && this.onItemAction) {
                      this.onItemAction(action, loadedItem);
                    }
                  }).catch((_err: Error) => {});
                }
              },
            })
          }
        }, (row: ItemTreeRowModel): string => row.id)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('100%')
  }

  /** Lazily load the ItemModel for a child row from the database. */
  private _loadItemForRow(row: ItemTreeRowModel): Promise<ItemModel | null> {
    if (row.item) { return Promise.resolve(row.item); }
    if (row.key.length === 0) { return Promise.resolve(null); }
    let repo = new LibraryRepository();
    let context = getContext(this).getApplicationContext();
    return repo.open(context).then(() => {
      return repo.getItemByKey(row.key);
    }).then((item: ItemModel | null) => {
      repo.close();
      return item;
    }).catch((_err: Error) => {
      repo.close();
      return null;
    });
  }

  private _onPendingSyncChanged(): void {
    this._applyPendingSyncFlags();
  }

  /** Re-apply pending flags to current rows without DB re-query. */
  private _applyPendingSyncFlags(): void {
    let copy = [...this.rows];
    applyPendingSyncToRows(copy, this.pendingSyncMap);
    this.rows = copy;
  }

  private _setRows(rows: ItemTreeRowModel[]): void {
    applyPendingSyncToRows(rows, this.pendingSyncMap);
    this.rows = rows;
  }

  private _toggleExpand(key: string): void {
    let idx = this.expandedKeys.indexOf(key);
    if (idx >= 0) {
      this.expandedKeys = this.expandedKeys.filter((k: string) => k !== key);
    } else {
      this.expandedKeys = [...this.expandedKeys, key];
    }
    this._rebuildRows();
  }

  /**
   * Rebuild flattened tree rows.  Queries child rows for ALL parent items
   * so that collapsed parents still know their childCount and show ▶.
   */
  private _rebuildRows(): void {
    let parentKeys = collectParentKeysForChildLookup(this.items);
    if (parentKeys.length === 0) {
      this._setRows(buildItemTreeRows(this.items, [], this.expandedKeys));
      return;
    }
    let repo = new LibraryRepository();
    let context = getContext(this).getApplicationContext();
    repo.open(context).then(() => {
      return repo.listChildRowsForItems(parentKeys);
    }).then((childRows: ItemChildSummary[]) => {
      this._setRows(buildItemTreeRows(this.items, childRows, this.expandedKeys));
      repo.close();
    }).catch((_err: Error) => {
      this._setRows(buildItemTreeRows(this.items, [], this.expandedKeys));
      repo.close();
    });
  }

  private _sortItems(): void {
    let foundCol = DEFAULT_COLUMNS.find((c: ItemTreeColumn) => c.dataKey === this.sortKey);
    if (!foundCol) { return; }
    let col = foundCol as ItemTreeColumn;
    let getVal = (item: ItemModel): string => col.render(item).toLowerCase();
    this.items = [...this.items].sort((a: ItemModel, b: ItemModel) => {
      let va = getVal(a);
      let vb = getVal(b);
      if (va < vb) { return this.sortAsc ? -1 : 1; }
      if (va > vb) { return this.sortAsc ? 1 : -1; }
      return 0;
    });
  }

  reload(): void {
    let context = getContext(this).getApplicationContext();
    let repo = new LibraryRepository();
    let requestedCollection = this.collectionKey.length > 0 ? this.collectionKey : null;
    repo.open(context).then(() => {
      if (this.viewMode === 'duplicates') {
        return repo.listDuplicateItems(this.filterText);
      }
      if (this.viewMode === 'unfiled') {
        return repo.listUnfiledItems(this.filterText);
      }
      if (this.viewMode === 'trash') {
        return repo.listTrashItems(this.filterText);
      }
      if (this.viewMode === 'search' && this.collectionKey.length > 0) {
        return repo.getSavedSearchQuery(this.collectionKey).then((savedSearch) => {
          return repo.listItems(null, '').then((items: ItemModel[]) => {
            if (!savedSearch) { return items; }
            let engine = new SearchEngine();
            engine.setJoinMode(savedSearch.joinMode);
            for (let i = 0; i < savedSearch.conditions.length; i++) {
              engine.addCondition(savedSearch.conditions[i].condition,
                savedSearch.conditions[i].operator, savedSearch.conditions[i].value,
                savedSearch.conditions[i].required);
            }
            let filtered = engine.filter(items);
            if (this.filterText.length === 0) { return filtered; }
            let needle = this.filterText.toLowerCase();
            return filtered.filter((item: ItemModel): boolean => {
              return (item.itemData.get('title') ?? '').toLowerCase().includes(needle) ||
                (item.itemData.get('creator') ?? '').toLowerCase().includes(needle) ||
                (item.itemData.get('date') ?? '').toLowerCase().includes(needle) ||
                (item.itemData.get('publisher') ?? '').toLowerCase().includes(needle);
            });
          });
        });
      }
      return repo.listItems(requestedCollection, this.filterText);
    }).then((loadedItems: ItemModel[]) => {
      this.items = loadedItems;
      if (this.excludeItemKeys.length > 0) {
        this.items = this.items.filter((item: ItemModel): boolean => {
          let key = item.key ?? '';
          return this.excludeItemKeys.indexOf(key) < 0;
        });
      }
      this._sortItems();
      this._rebuildRows();  // build tree rows from sorted items
      repo.close();
    }).catch((_err: Error) => {
      this.items = [];
      this.rows = [];
      repo.close();
    });
  }

  private _toggleColumn(dataKey: string): void {
    let visible = this.columns.findIndex((column: ItemTreeColumn) => column.dataKey === dataKey) >= 0;
    let visibleKeys: string[] = [];
    if (visible) {
      for (let i = 0; i < this.columns.length; i++) {
        if (this.columns[i].dataKey !== dataKey) {
          visibleKeys.push(this.columns[i].dataKey);
        }
      }
    } else {
      for (let j = 0; j < DEFAULT_COLUMNS.length; j++) {
        let column = DEFAULT_COLUMNS[j];
        if (this.columns.findIndex((item: ItemTreeColumn) => item.dataKey === column.dataKey) >= 0 || column.dataKey === dataKey) {
          visibleKeys.push(column.dataKey);
        }
      }
    }
    if (visibleKeys.length > 0) {
      this.columns = this._buildColumns(visibleKeys);
    }
    this._persistColumns();
  }

  private _resetColumns(): void {
    this.columns = DEFAULT_COLUMNS;
    this.sortKey = 'title';
    this.sortAsc = true;
    this._persistColumns();
    this._persistSort();
    this._sortItems();
    this._rebuildRows();
  }

  private _setSort(key: string, asc: boolean): void {
    this.sortKey = key;
    this.sortAsc = asc;
    this._persistSort();
    this._sortItems();
    this._rebuildRows();
  }

  private async _loadDisplayPreferences(): Promise<void> {
    await Preferences.init(getContext(this).getApplicationContext());
    let columnsValue = await Preferences.getString(PrefKey.ITEM_TREE_COLUMNS);
    let sortValue = await Preferences.getString(PrefKey.ITEM_TREE_SORT);

    let visibleKeys = this._parseColumnKeys(columnsValue);
    this.columns = this._buildColumns(visibleKeys);
    if (this.columns.length === 0) {
      this.columns = DEFAULT_COLUMNS;
    }

    let sortParts = sortValue.split(':');
    if (sortParts.length >= 1 && sortParts[0].length > 0) {
      this.sortKey = sortParts[0];
    }
    if (sortParts.length >= 2) {
      this.sortAsc = sortParts[1] !== 'desc';
    }
  }

  private _buildColumns(keys: string[]): ItemTreeColumn[] {
    let next: ItemTreeColumn[] = [];
    for (let i = 0; i < keys.length; i++) {
      let found = DEFAULT_COLUMNS.find((column: ItemTreeColumn) => column.dataKey === keys[i]);
      if (found) {
        next.push(found);
      }
    }
    return next;
  }

  private _parseColumnKeys(value: string): string[] {
    if (value.trim().length === 0) {
      return [];
    }
    let parts = value.split(',');
    let keys: string[] = [];
    for (let i = 0; i < parts.length; i++) {
      let key = parts[i].trim();
      if (key.length > 0 && keys.indexOf(key) < 0) {
        keys.push(key);
      }
    }
    return keys;
  }

  private _persistColumns(): void {
    let keys: string[] = [];
    for (let i = 0; i < this.columns.length; i++) {
      keys.push(this.columns[i].dataKey);
    }
    Preferences.set(PrefKey.ITEM_TREE_COLUMNS, keys.join(',')).catch((_err: Error) => {});
  }

  private _persistSort(): void {
    Preferences.set(PrefKey.ITEM_TREE_SORT, `${this.sortKey}:${this.sortAsc ? 'asc' : 'desc'}`).catch((_err: Error) => {});
  }
}
