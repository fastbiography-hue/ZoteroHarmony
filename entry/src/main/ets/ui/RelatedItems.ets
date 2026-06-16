/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: elements/relatedBox.js — related items panel (dc:relation)
 *
 * ***** END LICENSE BLOCK *****
 */

import { RelatedItemRef } from '../model/RelatedItemModel.ets';

@Component
struct RelatedItemRow {
  @Prop item: RelatedItemRef = { key: '', title: '', itemType: '', creators: '' };
  onSelect?: (key: string) => void;
  onRemove?: (key: string) => void;

  build() {
    Row() {
      Text('📄').fontSize(14).margin({ right: 8 })

      Column() {
        Text(this.item.title || '(untitled)')
          .fontSize(14).fontColor('#333').maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.item.creators)
          .fontSize(11).fontColor('#999').maxLines(1)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('✕').fontSize(12).width(28).height(28)
        .backgroundColor('#00000000').fontColor('#999')
        .onClick(() => { if (this.onRemove) { this.onRemove(this.item.key); } })
    }
    .width('100%').padding({ left: 12, right: 4, top: 6, bottom: 6 })
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
    .onClick(() => { if (this.onSelect) { this.onSelect(this.item.key); } })
  }
}

/**
 * Related items list.
 * Populated via dc:relation predicates from DataObject.getRelations().
 * Ref: elements/relatedBox.js
 */
@Component
export struct RelatedItems {
  @Link related: RelatedItemRef[];
  @Prop readOnly: boolean = false;
  onItemSelect?: (key: string) => void;
  onItemRemove?: (key: string) => void;
  onItemAdd?: () => void;

  build() {
    Column() {
      Row() {
        Text('RELATED ITEMS')
          .fontSize(11).fontColor('#888').fontWeight(FontWeight.Medium)
          .layoutWeight(1)
        if (!this.readOnly) {
          Button('+ Add').fontSize(12).height(28)
            .onClick(() => { if (this.onItemAdd) { this.onItemAdd(); } })
        }
      }
      .width('100%').padding({ left: 12, right: 12, top: 8, bottom: 4 })

      if (this.related.length === 0) {
        Text('No related items').fontSize(13).fontColor('#CCC')
          .padding({ left: 12, bottom: 8 })
      } else {
        List() {
          ForEach(this.related, (ref: RelatedItemRef) => {
            ListItem() {
              RelatedItemRow({
                item: ref,
                onSelect: this.onItemSelect,
                onRemove: (key: string) => {
                  this.related = this.related.filter((r: RelatedItemRef) => r.key !== key);
                  if (this.onItemRemove) { this.onItemRemove(key); }
                },
              })
            }
          }, (ref: RelatedItemRef): string => `rel-${ref.key}`)
        }
        .height(Math.min(this.related.length * 52, 260))
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .border({ width: { top: 1 }, color: '#EEEEEE' })
  }
}
