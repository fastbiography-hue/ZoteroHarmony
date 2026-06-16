/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: itemTree.jsx — item list with search highlighting
 *
 * ***** END LICENSE BLOCK *****
 */

import { ItemModel } from '../model/ItemModel.ets';

/** A search result with highlighted match ranges. */
export interface SearchResultItem {
  item: ItemModel;
  matchField: string;
  matchPreview: string;   // snippet around the match
}

@Component
struct ResultRow {
  @Prop result: SearchResultItem = { item: new ItemModel(), matchField: '', matchPreview: '' };
  onOpen?: (item: ItemModel) => void;
  @StorageLink('zotero_theme') themeMode: string = 'light';

  build() {
    Column() {
      Row() {
        Column() {
          Text(this.result.item.displayTitle ?? this.result.item.itemData.get('title') ?? '(untitled)')
            .fontSize(14).fontColor(this.themeMode === 'dark' ? '#F4F6FA' : '#333').fontWeight(FontWeight.Medium)
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this._creatorLine())
            .fontSize(12).fontColor(this.themeMode === 'dark' ? '#AAB4C2' : '#999').maxLines(1)
          Row() {
            Text(this.result.matchField)
              .fontSize(10).fontColor('#FFF').backgroundColor('#CC3333')
              .borderRadius(3).padding({ left: 5, right: 5, top: 1, bottom: 1 })
            Text(` ${this.result.matchPreview}`)
              .fontSize(12).fontColor(this.themeMode === 'dark' ? '#AAB4C2' : '#666').maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .margin({ top: 4 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 12, top: 8, bottom: 8 })
      }
      .width('100%')
      .onClick(() => { if (this.onOpen) { this.onOpen(this.result.item); } })

      Divider().color(this.themeMode === 'dark' ? '#252C38' : '#F0F0F0')
    }
    .width('100%')
  }

  private _creatorLine(): string {
    let creators = this.result.item.creators;
    if (creators.length === 0) { return ''; }
    let names: string[] = [];
    for (let i = 0; i < Math.min(creators.length, 3); i++) {
      names.push(creators[i].lastName || creators[i].firstName);
    }
    let line = names.join('; ');
    if (creators.length > 3) { line += ' et al.'; }
    return line;
  }
}

/**
 * Search results list with matched-field annotations.
 */
@Component
export struct SearchResultsList {
  @Link results: SearchResultItem[];
  @Prop emptyMessage: string = 'No results found';
  onItemOpen?: (item: ItemModel) => void;
  @StorageLink('zotero_theme') themeMode: string = 'light';

  build() {
    Column() {
      if (this.results.length === 0) {
        Column() {
          Text('🔍').fontSize(36).margin({ bottom: 12 })
          Text(this.emptyMessage).fontSize(15).fontColor(this.themeMode === 'dark' ? '#AAB4C2' : '#999')
        }
        .width('100%').layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Row() {
          Text(`${this.results.length} result${this.results.length === 1 ? '' : 's'}`)
            .fontSize(12).fontColor(this.themeMode === 'dark' ? '#AAB4C2' : '#999')
            .padding({ left: 12, top: 6, bottom: 6 })
        }

        List() {
          ForEach(this.results, (r: SearchResultItem) => {
            ListItem() {
              ResultRow({
                result: r,
                onOpen: this.onItemOpen,
              })
            }
          }, (r: SearchResultItem): string => `sr-${r.item.id}`)
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%').height('100%')
    .backgroundColor(this.themeMode === 'dark' ? '#11151B' : '#FFFFFF')
  }
}
