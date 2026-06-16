/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: elements/itemBox.js  creator editing section
 *
 * ***** END LICENSE BLOCK *****
 */

import { ZoteroCreator } from '../model/ItemTypes.ets';

const TYPE_LABELS: Record<string, string> = {
  'author': 'Author', 'editor': 'Editor', 'translator': 'Translator',
  'contributor': 'Contributor', 'bookAuthor': 'Book Author',
};

@Component
struct CreatorRow {
  @Prop creator: ZoteroCreator = { creatorType: 'author', firstName: '', lastName: '', fieldMode: 0 };
  @Prop index: number = 0;
  onUpdate?: (index: number, c: ZoteroCreator) => void;
  onDelete?: (index: number) => void;

  build() {
    Row() {
      Text(TYPE_LABELS[this.creator.creatorType] ?? this.creator.creatorType)
        .fontSize(10).fontColor('#FFF').backgroundColor('#CC3333')
        .borderRadius(4).padding({ left: 6, right: 6, top: 2, bottom: 2 })
        .margin({ right: 8 })

      TextInput({ placeholder: 'Last', text: this.creator.lastName })
        .fontSize(14).layoutWeight(1).height(36)
        .onChange((v: string) => {
          if (this.onUpdate) {
            this.onUpdate(this.index, {
              creatorType: this.creator.creatorType,
              firstName: this.creator.firstName,
              lastName: v,
              fieldMode: this.creator.fieldMode,
            });
          }
        })
      TextInput({ placeholder: 'First', text: this.creator.firstName })
        .fontSize(14).layoutWeight(1).height(36).margin({ left: 4 })
        .onChange((v: string) => {
          if (this.onUpdate) {
            this.onUpdate(this.index, {
              creatorType: this.creator.creatorType,
              firstName: v,
              lastName: this.creator.lastName,
              fieldMode: this.creator.fieldMode,
            });
          }
        })
      Button('✕').fontSize(12).width(32).height(32)
        .backgroundColor('#00000000').fontColor('#999')
        .margin({ left: 4 })
        .onClick(() => { if (this.onDelete) { this.onDelete(this.index); } })
    }
    .width('100%').padding({ left: 12, right: 8, top: 4, bottom: 4 })
  }
}

/**
 * Editable creator list with add/remove.
 * Ref: item.js  getCreatorsJSON() / setCreators()
 */
@Component
export struct CreatorEditor {
  @Link creators: ZoteroCreator[];
  @Prop readOnly: boolean = false;
  onCreatorsChange?: (creators: ZoteroCreator[]) => void;

  build() {
    Column() {
      Row() {
        Text('CREATORS').fontSize(11).fontColor('#888')
          .fontWeight(FontWeight.Medium).layoutWeight(1)
        if (!this.readOnly) {
          Button('+ Add').fontSize(12).height(28).onClick(() => {
            let newCreator: ZoteroCreator = {
              creatorType: 'author', firstName: '', lastName: '', fieldMode: 0
            };
            let next: ZoteroCreator[] = [...this.creators, newCreator];
            this.creators = next;
            if (this.onCreatorsChange) { this.onCreatorsChange(next); }
          })
        }
      }
      .width('100%').padding({ left: 12, right: 12, top: 8, bottom: 4 })

      ForEach(this.creators, (creator: ZoteroCreator, idx: number) => {
        CreatorRow({
          creator: creator, index: idx,
          onUpdate: (i: number, c: ZoteroCreator) => {
            let copy = [...this.creators]; copy[i] = c; this.creators = copy;
            if (this.onCreatorsChange) { this.onCreatorsChange(copy); }
          },
          onDelete: (i: number) => {
            let copy = [...this.creators]; copy.splice(i, 1); this.creators = copy;
            if (this.onCreatorsChange) { this.onCreatorsChange(copy); }
          },
        })
      }, (_item: ZoteroCreator, index: number): string => `cr-${index}`)
    }
    .width('100%')
  }
}
