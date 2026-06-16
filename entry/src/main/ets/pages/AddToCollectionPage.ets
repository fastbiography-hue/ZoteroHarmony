/*
 * Select a destination collection and add currently selected items to it.
 */

import { router } from '@kit.ArkUI';
import { CollectionTree } from '../ui/tree/CollectionTree.ets';
import { CollectionTreeRow } from '../ui/tree/CollectionTreeRow.ets';
import { LibraryRepository } from '../database/LibraryRepository.ets';
import { AppStore } from '../utils/AppStore.ets';
import { ZHColor, ZHMetric } from '../theme/ThemeConstants.ets';

@Entry
@Component
struct AddToCollectionPage {
  @State selectedRowID: string = 'L1';
  @State selectedCollectionKey: string = '';
  @State selectedCollectionName: string = '';
  @State itemKeys: string[] = [];
  @State statusText: string = '';
  @State busy: boolean = false;
  @StorageLink('zotero_theme') themeMode: string = 'light';

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, Object>;
    let keyParam = (params?.['itemKeys'] as string) ?? '';
    this.itemKeys = keyParam.length > 0 ? keyParam.split(',').filter((value: string) => value.length > 0) : [];
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
          Text('Add to Collection')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
          Text(`${this.itemKeys.length} selected item${this.itemKeys.length === 1 ? '' : 's'}`)
            .fontSize(11)
            .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
        }
        .layoutWeight(1)
        Button(this.busy ? 'Adding…' : 'Add')
          .fontSize(12)
          .height(32)
          .backgroundColor(ZHColor.BRAND)
          .fontColor(ZHColor.TEXT_INVERSE)
          .enabled(!this.busy && this.selectedCollectionKey.length > 0 && this.itemKeys.length > 0)
          .onClick(() => { this._applySelection(); })
      }
      .width('100%')
      .height(ZHMetric.TOOLBAR_HEIGHT)
      .padding({ left: 8, right: 10 })
      .border({ width: { bottom: 1 }, color: this.themeMode === 'dark' ? '#303846' : ZHColor.BORDER })

      Row() {
        Column() {
          Text('Collections')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(ZHColor.TEXT_MUTED)
            .padding({ left: 12, top: 10, bottom: 8 })
          CollectionTree({
            selectedRowID: $selectedRowID,
            revision: 0,
            onRowSelected: (row: CollectionTreeRow) => {
              if (row.type === 'collection') {
                this.selectedCollectionKey = row.key ?? '';
                this.selectedCollectionName = row.name;
              } else {
                this.selectedCollectionKey = '';
                this.selectedCollectionName = '';
              }
            },
          })
        }
        .width('45%')
        .backgroundColor(this.themeMode === 'dark' ? '#171B22' : ZHColor.SURFACE_SIDEBAR)
        .border({ width: { right: 1 }, color: this.themeMode === 'dark' ? '#303846' : ZHColor.BORDER })

        Column() {
          Text('Destination')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(ZHColor.TEXT_MUTED)
            .padding({ left: 12, top: 10, bottom: 8 })
          Column() {
            if (this.selectedCollectionKey.length > 0) {
              Text(this.selectedCollectionName)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
              Text(this.selectedCollectionKey)
                .fontSize(12)
                .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
                .margin({ top: 6 })
            } else {
              Text('Select a collection from the left pane')
                .fontSize(14)
                .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
            }
          }
          .width('100%')
          .padding(16)

          if (this.statusText.length > 0) {
            Text(this.statusText)
              .fontSize(12)
              .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
              .padding({ left: 16, right: 16, top: 4 })
          }
        }
        .layoutWeight(1)
        .backgroundColor(this.themeMode === 'dark' ? '#11151B' : ZHColor.SURFACE)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeMode === 'dark' ? '#11151B' : ZHColor.SURFACE)
  }

  private async _applySelection(): Promise<void> {
    if (this.busy || this.selectedCollectionKey.length === 0 || this.itemKeys.length === 0) {
      return;
    }
    this.busy = true;
    let repo = new LibraryRepository();
    try {
      await repo.open(getContext(this).getApplicationContext());
      await repo.addItemsToCollection(this.itemKeys, this.selectedCollectionKey);
      await repo.close();
      this.statusText = `Added ${this.itemKeys.length} item${this.itemKeys.length === 1 ? '' : 's'} to ${this.selectedCollectionName}`;
      AppStore.libraryRevision = AppStore.libraryRevision + 1;
      setTimeout(() => { router.back(); }, 180);
    } catch (_err) {
      this.statusText = 'Could not add items to collection';
      try { await repo.close(); } catch (_e) {}
    } finally {
      this.busy = false;
    }
  }
}
