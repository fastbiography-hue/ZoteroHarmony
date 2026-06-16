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
import { LibraryRepository } from '../../database/LibraryRepository.ets';
import { SearchEngine } from '../../search/SearchEngine.ets';
import { ItemTreeToolbar } from '../ItemTreeToolbar.ets';

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
 * Virtualized item list with multi-column layout.
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
  @State columns: ItemTreeColumn[] = DEFAULT_COLUMNS;
  @State sortKey: string = 'title';
  @State sortAsc: boolean = true;
  @StorageLink('zotero_theme') themeMode: string = 'light';
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
        // Column headers
        Row() {
          ForEach(this.columns, (col: ItemTreeColumn) => {
            Row() {
              Text(col.label)
                .fontSize(11).fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
                .fontWeight(FontWeight.Bold)
                .textCase(TextCase.UpperCase)

              if (col.sortable && this.sortKey === col.dataKey) {
                Text(this.sortAsc ? ' ▲' : ' ▼')
                  .fontSize(10).fontColor(ZHColor.BRAND)
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

      // Item rows
      List() {
        ForEach(this.items, (item: ItemModel) => {
          let itemKey = item.key ?? '';
          let needle = this.filterText.toLowerCase();
          let matches = this.filterText.length === 0 ||
            (item.itemData.get('title') ?? '').toLowerCase().includes(needle) ||
            (item.itemData.get('creator') ?? '').toLowerCase().includes(needle) ||
            (item.itemData.get('date') ?? '').toLowerCase().includes(needle) ||
            (item.itemData.get('publisher') ?? '').toLowerCase().includes(needle);
          if (matches && this.excludeItemKeys.indexOf(itemKey) < 0) {
            ListItem() {
              ItemRow({
                item: item,
                columns: this.columns,
                isSelected: this.selectedItemKey === (item.key ?? `${item.itemData.get('title') ?? 'item'}-${item.itemData.get('date') ?? ''}`),
                isChecked: this.selectedItemKeys.indexOf(item.key ?? `${item.itemData.get('title') ?? 'item'}-${item.itemData.get('date') ?? ''}`) >= 0,
                themeMode: this.themeMode,
                viewMode: this.viewMode,
                showMenu: this.showRowMenu,
                onTap: (it: ItemModel) => {
                  this.selectedItemKey = it.key ?? `${it.itemData.get('title') ?? 'item'}-${it.itemData.get('date') ?? ''}`;
                  this.selectedItemKeys = [this.selectedItemKey];
                  AppStore.selectedItemKey = this.selectedItemKey;
                  if (this.onItemSelected) { this.onItemSelected(it); }
                },
                onCheck: (it: ItemModel, checked: boolean) => {
                  let key = it.key ?? `${it.itemData.get('title') ?? 'item'}-${it.itemData.get('date') ?? ''}`;
                  if (checked) {
                    let nextKeys = [...this.selectedItemKeys];
                    if (nextKeys.indexOf(key) < 0) {
                      nextKeys.push(key);
                    }
                    this.selectedItemKeys = nextKeys;
                    this.selectedItemKey = key;
                    AppStore.selectedItemKey = key;
                    if (this.onItemSelected) { this.onItemSelected(it); }
                  } else {
                    this.selectedItemKeys = this.selectedItemKeys.filter((selectedKey: string): boolean => selectedKey !== key);
                    if (this.selectedItemKey === key) {
                      this.selectedItemKey = this.selectedItemKeys.length > 0 ? this.selectedItemKeys[0] : '';
                      AppStore.selectedItemKey = this.selectedItemKey;
                    }
                  }
                },
                onMenuAction: (action: string, it: ItemModel) => {
                  this.selectedItemKey = it.key ?? `${it.itemData.get('title') ?? 'item'}-${it.itemData.get('date') ?? ''}`;
                  this.selectedItemKeys = [this.selectedItemKey];
                  AppStore.selectedItemKey = this.selectedItemKey;
                  if (this.showRowMenu && this.onItemAction) { this.onItemAction(action, it); }
                },
              })
            }
          }
        }, (item: ItemModel): string => item.key ?? `${item.itemData.get('title') ?? 'item'}-${item.itemData.get('date') ?? ''}`)
      }
      .layoutWeight(1)
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%').height('100%')
  }

  /** Sort items by sortKey/sortAsc. */
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
            if (!savedSearch) {
              return items;
            }
            let engine = new SearchEngine();
            engine.setJoinMode(savedSearch.joinMode);
            for (let i = 0; i < savedSearch.conditions.length; i++) {
              let cond = savedSearch.conditions[i];
              engine.addCondition(cond.condition, cond.operator, cond.value, cond.required);
            }
            let filtered = engine.filter(items);
            if (this.filterText.length === 0) {
              return filtered;
            }
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
      repo.close();
    }).catch((_err: Error) => {
      this.items = [];
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
  }

  private _setSort(key: string, asc: boolean): void {
    this.sortKey = key;
    this.sortAsc = asc;
    this._persistSort();
    this._sortItems();
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
