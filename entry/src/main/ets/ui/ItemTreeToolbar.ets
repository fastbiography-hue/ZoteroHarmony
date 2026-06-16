/*
 * Toolbar for item-tree display controls: visible columns and sort order.
 */

import { ItemTreeColumn, DEFAULT_COLUMNS } from './table/ItemTreeColumns.ets';
import { ZHColor } from '../theme/ThemeConstants.ets';

@Component
export struct ItemTreeToolbar {
  @Prop columns: ItemTreeColumn[] = [];
  @Prop sortKey: string = 'title';
  @Prop sortAsc: boolean = true;
  @StorageLink('zotero_theme') themeMode: string = 'light';
  onToggleColumn?: (dataKey: string) => void;
  onResetColumns?: () => void;
  onSortChange?: (sortKey: string, sortAsc: boolean) => void;

  build() {
    Row() {
      Button('Columns')
        .fontSize(12)
        .height(30)
        .backgroundColor(this.themeMode === 'dark' ? '#242A33' : ZHColor.SURFACE_ALT)
        .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
        .bindMenu(this._columnsMenu)

      Button(`Sort: ${this._sortLabel()}`)
        .fontSize(12)
        .height(30)
        .margin({ left: 8 })
        .backgroundColor(this.themeMode === 'dark' ? '#242A33' : ZHColor.SURFACE_ALT)
        .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
        .bindMenu(this._sortMenu)

      Button('Reset')
        .fontSize(12)
        .height(30)
        .margin({ left: 8 })
        .backgroundColor(ZHColor.BRAND_SOFT)
        .fontColor(ZHColor.BRAND)
        .onClick(() => {
          if (this.onResetColumns) {
            this.onResetColumns();
          }
        })

      Blank().layoutWeight(1)
    }
    .width('100%')
    .height(40)
    .padding({ left: 10, right: 10 })
    .backgroundColor(this.themeMode === 'dark' ? '#11151B' : ZHColor.SURFACE)
    .border({ width: { bottom: 1 }, color: this.themeMode === 'dark' ? '#252C38' : ZHColor.BORDER_SOFT })
  }

  @Builder
  _columnsMenu() {
    Column() {
      ForEach(DEFAULT_COLUMNS, (column: ItemTreeColumn) => {
        Button(`${this._isColumnVisible(column.dataKey) ? '✓ ' : '  '}${column.label}`)
          .fontSize(13)
          .height(34)
          .width('100%')
          .backgroundColor('#00000000')
          .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
          .onClick(() => {
            if (this.onToggleColumn) {
              this.onToggleColumn(column.dataKey);
            }
          })
      }, (column: ItemTreeColumn): string => column.dataKey)
    }
    .padding(6)
    .backgroundColor(this.themeMode === 'dark' ? '#1B2028' : '#FFFFFF')
  }

  @Builder
  _sortMenu() {
    Column() {
      ForEach(DEFAULT_COLUMNS, (column: ItemTreeColumn) => {
        Button(`${this.sortKey === column.dataKey ? (this.sortAsc ? '▲ ' : '▼ ') : '  '}${column.label}`)
          .fontSize(13)
          .height(34)
          .width('100%')
          .backgroundColor('#00000000')
          .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
          .onClick(() => {
            if (this.onSortChange) {
              let nextAsc = this.sortKey === column.dataKey ? !this.sortAsc : true;
              this.onSortChange(column.dataKey, nextAsc);
            }
          })
      }, (column: ItemTreeColumn): string => `sort-${column.dataKey}`)
    }
    .padding(6)
    .backgroundColor(this.themeMode === 'dark' ? '#1B2028' : '#FFFFFF')
  }

  private _isColumnVisible(dataKey: string): boolean {
    return this.columns.findIndex((item: ItemTreeColumn): boolean => item.dataKey === dataKey) >= 0;
  }

  private _sortLabel(): string {
    let found = DEFAULT_COLUMNS.find((column: ItemTreeColumn) => column.dataKey === this.sortKey);
    if (!found) {
      return `${this.sortKey}${this.sortAsc ? ' ▲' : ' ▼'}`;
    }
    return `${found.label}${this.sortAsc ? ' ▲' : ' ▼'}`;
  }
}
