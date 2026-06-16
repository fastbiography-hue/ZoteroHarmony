/*
 * Select one or more items and add them as related items.
 */

import { router } from '@kit.ArkUI';
import { AppStore } from '../utils/AppStore.ets';
import { ZHColor, ZHMetric } from '../theme/ThemeConstants.ets';
import { QuickSearchBar } from '../ui/QuickSearchBar.ets';
import { ItemTree } from '../ui/tree/ItemTree.ets';
import { ItemModel } from '../model/ItemModel.ets';
import { LibraryRepository } from '../database/LibraryRepository.ets';

@Entry
@Component
struct SelectItemsDialog {
  @State itemKey: string = '';
  @State queryText: string = '';
  @State selectedItemKey: string = '';
  @State selectedItemKeys: string[] = [];
  @State statusText: string = '';
  @StorageLink('zotero_theme') themeMode: string = 'light';

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, Object>;
    this.itemKey = (params?.['itemKey'] as string) ?? '';
  }

  build() {
    Column() {
      Row() {
        Button('←')
          .fontSize(20)
          .width(40)
          .height(40)
          .backgroundColor(ZHColor.TRANSPARENT)
          .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
          .onClick(() => { router.back(); })
        Column() {
          Text('Select Related Items')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
          Text(`${this.selectedItemKeys.length} selected`)
            .fontSize(11)
            .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
        }
        .layoutWeight(1)
        Button('Add')
          .fontSize(12)
          .height(32)
          .backgroundColor(ZHColor.BRAND)
          .fontColor(ZHColor.TEXT_INVERSE)
          .enabled(this.selectedItemKeys.length > 0 && this.itemKey.length > 0)
          .onClick(() => { this._applySelection(); })
      }
      .width('100%')
      .height(ZHMetric.TOOLBAR_HEIGHT)
      .padding({ left: 8, right: 10 })
      .border({ width: { bottom: 1 }, color: this.themeMode === 'dark' ? '#303846' : ZHColor.BORDER })

      Row() {
        QuickSearchBar({
          inputText: $queryText,
          placeholder: 'Search items to relate…',
          onSearch: (text: string) => { this.queryText = text; },
        })
        .layoutWeight(1)
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .backgroundColor(this.themeMode === 'dark' ? '#11151B' : ZHColor.SURFACE)

      ItemTree({
        selectedItemKey: $selectedItemKey,
        selectedItemKeys: $selectedItemKeys,
        collectionKey: '',
        filterText: this.queryText,
        revision: AppStore.libraryRevision,
        viewMode: 'collection',
        showToolbar: false,
        showHeaders: false,
        showRowMenu: false,
        excludeItemKeys: this.itemKey.length > 0 ? [this.itemKey] : [],
        onItemSelected: (_item: ItemModel) => {},
      })
      .layoutWeight(1)

      if (this.statusText.length > 0) {
        Text(this.statusText)
          .fontSize(12)
          .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
          .padding({ left: 12, right: 12, bottom: 8, top: 6 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeMode === 'dark' ? '#11151B' : ZHColor.SURFACE)
  }

  private _applySelection(): void {
    if (this.itemKey.length === 0 || this.selectedItemKeys.length === 0) {
      return;
    }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.addRelatedItems(this.itemKey, this.selectedItemKeys);
    }).then(() => {
      AppStore.libraryRevision = AppStore.libraryRevision + 1;
      this.statusText = `Added ${this.selectedItemKeys.length} related item${this.selectedItemKeys.length === 1 ? '' : 's'}`;
      setTimeout(() => { router.back(); }, 180);
      repo.close();
    }).catch((_err: Error) => {
      this.statusText = 'Could not add related items';
      repo.close();
    });
  }
}
