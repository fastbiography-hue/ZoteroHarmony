/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: elements/tagsBox.js — tag editor with bubble chips
 *
 * ***** END LICENSE BLOCK *****
 */

import { ZoteroTag } from '../model/ItemTypes.ets';

/** Single tag chip. */
@Component
struct TagChip {
  @Prop tag: ZoteroTag = { tag: '', type: 0 };
  @Prop readOnly: boolean = false;
  onRemove?: (tag: string) => void;

  build() {
    Row() {
      Text(this.tag.tag)
        .fontSize(13)
        .fontColor('#333333')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      if (!this.readOnly && this.onRemove) {
        Text('✕')
          .fontSize(11)
          .fontColor('#999999')
          .margin({ left: 4 })
          .onClick(() => { if (this.onRemove) { this.onRemove(this.tag.tag); } })
      }
    }
    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
    .backgroundColor(this.tag.type === 1 ? '#E3F2FD' : '#F5F5F5')
    .borderRadius(14)
    .margin({ right: 6, bottom: 6 })
  }
}

/**
 * Tag editor with chip-style display + add input.
 * Ref: elements/tagsBox.js
 */
@Component
export struct TagChipEditor {
  @Link tags: ZoteroTag[];
  @Prop readOnly: boolean = false;
  @State newTagText: string = '';
  onTagsChange?: (tags: ZoteroTag[]) => void;

  build() {
    Column() {
      // Header
      Text('TAGS').fontSize(11).fontColor('#888')
        .fontWeight(FontWeight.Medium).width('100%')
        .padding({ left: 12, top: 8, bottom: 4 })

      // Add input
      if (!this.readOnly) {
        Row() {
          TextInput({ placeholder: 'Add tag…', text: this.newTagText })
            .fontSize(14).height(36).layoutWeight(1)
            .onChange((v: string) => { this.newTagText = v.trim(); })
            .onSubmit(() => { this._addTag(); })

          Button('Add')
            .fontSize(12).height(32).margin({ left: 8 })
            .enabled(this.newTagText.length > 0)
            .onClick(() => { this._addTag(); })
        }
        .width('100%').padding({ left: 12, right: 12, bottom: 8 })
      }

      // Chip list — use Flex wrap for flow layout
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.tags, (tag: ZoteroTag, idx: number) => {
          TagChip({
            tag: tag,
            readOnly: this.readOnly,
            onRemove: (name: string) => {
              this.tags = this.tags.filter((t: ZoteroTag) => t.tag !== name);
              if (this.onTagsChange) { this.onTagsChange(this.tags); }
            },
          })
        }, (_item: ZoteroTag, index: number): string => `tag-${index}`)
      }
      .padding({ left: 12, right: 12, bottom: 8 })

      if (this.tags.length === 0) {
        Text('No tags')
          .fontSize(13).fontColor('#CCCCCC')
          .padding({ left: 12, bottom: 8 })
      }
    }
    .width('100%')
  }

  private _addTag(): void {
    if (!this.newTagText) { return; }
    // Prevent duplicate
    for (let i = 0; i < this.tags.length; i++) {
      if (this.tags[i].tag === this.newTagText) { this.newTagText = ''; return; }
    }
    this.tags = [...this.tags, { tag: this.newTagText, type: 0 }];
    if (this.onTagsChange) { this.onTagsChange(this.tags); }
    this.newTagText = '';
  }
}
