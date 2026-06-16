/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: reader/src/common/components/toolbar/
 *
 * ***** END LICENSE BLOCK *****
 */

import { AnnotationType, ANNOTATION_COLORS } from './ReaderTypes.ets';

export type ReaderTool = 'pan' | 'highlight' | 'underline' | 'note' | 'select';

export interface ReaderToolEntry {
  tool: ReaderTool;
  icon: string;
  label: string;
}

const readerTools: ReaderToolEntry[] = [
  { tool: 'pan', icon: '✋', label: 'Pan' },
  { tool: 'highlight', icon: '🖍', label: 'Highlight' },
  { tool: 'underline', icon: 'U̲', label: 'Underline' },
  { tool: 'note', icon: '💬', label: 'Note' },
  { tool: 'select', icon: '📋', label: 'Select' },
];

@Component
export struct ReaderToolbar {
  @Link selectedTool: ReaderTool;
  @Link selectedColor: string;
  @StorageLink('zotero_theme') themeMode: string = 'light';
  @Prop currentPage: number = 1;
  @Prop totalPages: number = 1;
  @Prop docTitle: string = '';
  onToolChange?: (t: ReaderTool) => void;
  onColorChange?: (c: string) => void;
  onPageChange?: (p: number) => void;
  onClose?: () => void;

  build() {
    Column() {
      // Title row
      Row() {
        Text(this.docTitle)
          .fontSize(14).fontColor(this.themeMode === 'dark' ? '#F4F6FA' : '#333')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
        Button('✕').fontSize(16).width(36).height(36)
          .backgroundColor('#00000000').fontColor('#666')
          .onClick(() => { if (this.onClose) { this.onClose(); } })
      }
      .width('100%').height(40).padding({ left: 12, right: 4 })

      // Tool row
      Row() {
        ForEach(readerTools, (entry: ReaderToolEntry) => {
          Column() {
            Text(entry.icon).fontSize(20)
          }
          .width(44).height(40)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.selectedTool === entry.tool ? (this.themeMode === 'dark' ? '#263247' : '#E3F2FD') : '#00000000')
          .borderRadius(8)
          .margin({ left: 4, right: 4 })
          .onClick(() => {
            this.selectedTool = entry.tool;
            if (this.onToolChange) { this.onToolChange(entry.tool); }
          })
        }, (entry: ReaderToolEntry): string => entry.tool)

        Blank()

        // Page nav
        Text('←').fontSize(18).width(32).textAlign(TextAlign.Center)
          .onClick(() => {
            if (this.currentPage > 1 && this.onPageChange) {
              this.onPageChange(this.currentPage - 1);
            }
          })
        Text(`${this.currentPage}/${this.totalPages}`)
          .fontSize(13).fontColor('#666').width(50).textAlign(TextAlign.Center)
        Text('→').fontSize(18).width(32).textAlign(TextAlign.Center)
          .onClick(() => {
            if (this.currentPage < this.totalPages && this.onPageChange) {
              this.onPageChange(this.currentPage + 1);
            }
          })
      }
      .width('100%').height(44)

      // Color row
      Row() {
        ForEach(ANNOTATION_COLORS, (color: string) => {
          Column()
            .width(24).height(24)
            .borderRadius(12)
            .backgroundColor(color)
            .border({
              width: this.selectedColor === color ? 2 : 0,
              color: this.themeMode === 'dark' ? '#D4D9E3' : '#333333',
            })
            .margin({ left: 4, right: 4 })
            .onClick(() => {
              this.selectedColor = color;
              if (this.onColorChange) { this.onColorChange(color); }
            })
        }, (color: string): string => color)
      }
      .width('100%').height(36)
    }
    .width('100%')
    .backgroundColor(this.themeMode === 'dark' ? '#171B22' : '#FAFAFA')
    .border({ width: { bottom: 1 }, color: this.themeMode === 'dark' ? '#303846' : '#E0E0E0' })
  }
}
