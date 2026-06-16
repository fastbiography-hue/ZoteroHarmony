/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: elements/abstractBox.js — abstract text area
 *
 * ***** END LICENSE BLOCK *****
 */

/**
 * Abstract / summary text editor.
 * Supports plain text with configurable height.
 */
@Component
export struct AbstractEditor {
  @Prop text: string = '';
  @Prop label: string = 'ABSTRACT';
  @Prop readOnly: boolean = false;
  @Prop minHeight: number = 120;
  onChange?: (text: string) => void;

  build() {
    Column() {
      Text(this.label)
        .fontSize(11).fontColor('#888').fontWeight(FontWeight.Medium)
        .width('100%').padding({ left: 12, top: 8, bottom: 4 })

      if (this.readOnly) {
        Text(this.text || 'No abstract')
          .fontSize(14).fontColor(this.text ? '#333' : '#CCC')
          .width('100%')
          .padding({ left: 12, right: 12, bottom: 12 })
          .textAlign(TextAlign.Start)
      } else {
        TextArea({ text: this.text, placeholder: 'Enter abstract or summary…' })
          .fontSize(14)
          .height(this.minHeight)
          .width('100%')
          .padding({ left: 12, right: 12 })
          .onChange((value: string) => {
            if (this.onChange) { this.onChange(value); }
          })
      }
    }
    .width('100%')
    .border({ width: { top: 1 }, color: '#EEEEEE' })
  }
}
