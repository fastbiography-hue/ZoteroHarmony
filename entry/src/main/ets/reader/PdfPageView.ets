/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: reader/src/ — PDF page rendering + annotation overlay
 *
 * ***** END LICENSE BLOCK *****
 */

import { PdfAnnotation, ANNOTATION_COLORS } from './ReaderTypes.ets';

/** Create an empty annotation for defaults. */
function emptyAnnotation(): PdfAnnotation {
  return {
    id: '', type: 'highlight', pageIndex: 0,
    position: { x: 0, y: 0, width: 0, height: 0 },
    color: '#FFD700', sortIndex: '0', dateModified: '',
  };
}

/** Single annotation rendered on top of the PDF page. */
@Component
struct AnnotationRect {
  @Prop annotation: PdfAnnotation = emptyAnnotation();
  @Prop isSelected: boolean = false;
  @StorageLink('zotero_theme') themeMode: string = 'light';
  onTap?: (ann: PdfAnnotation) => void;

  build() {
    Column()
      .width(`${this.annotation.position.width * 100}%`)
      .height(`${this.annotation.position.height * 100}%`)
      .position({
        x: `${this.annotation.position.x * 100}%`,
        y: `${this.annotation.position.y * 100}%`,
      })
      .backgroundColor(this._renderColor())
      .border({
        width: this.isSelected ? 2 : 0,
        color: this.themeMode === 'dark' ? '#D4D9E3' : '#333333',
        radius: 2,
      })
      .borderRadius(2)
      .onClick(() => { if (this.onTap) { this.onTap(this.annotation); } })
  }

  private _renderColor(): string {
    switch (this.annotation.type) {
      case 'highlight':  return `${this.annotation.color}40`; // 25% opacity
      case 'underline':  return '#00000000';
      case 'note':       return '#FFEAA730';
      case 'image':      return '#00000000';
      default:           return '#00000000';
    }
  }
}

/**
 * A single PDF page with annotation overlay.
 *
 * Uses a Web component to render the PDF page (via PDF.js in WebView)
 * with a translucent overlay for annotations.
 */
@Component
export struct PdfPageView {
  @Prop pageIndex: number = 0;
  @Prop filePath: string = '';
  @Prop annotations: PdfAnnotation[] = [];
  @Prop selectedAnnotationID: string = '';
  @Prop pageWidth: number = 360;
  @Prop pageHeight: number = 500;
  @StorageLink('zotero_theme') themeMode: string = 'light';
  onAnnotationTap?: (ann: PdfAnnotation) => void;

  build() {
    Stack() {
      // PDF page — rendered via Web component or Image
      // In production: load from filePath + pageIndex via PDF.js in WebView
      Column() {
        Text(`Page ${this.pageIndex + 1}`)
          .fontSize(48)
          .fontColor(this.themeMode === 'dark' ? '#4A5363' : '#CCCCCC')
          .fontWeight(FontWeight.Bold)
      }
      .width(this.pageWidth)
      .height(this.pageHeight)
      .backgroundColor(this.themeMode === 'dark' ? '#11151B' : '#FAFAFA')
      .justifyContent(FlexAlign.Center)
      .border({ width: 1, color: this.themeMode === 'dark' ? '#303846' : '#E0E0E0', radius: 4 })

      // Annotation overlay
      Column() {
        ForEach(this.annotations.filter((a: PdfAnnotation) => a.pageIndex === this.pageIndex),
          (ann: PdfAnnotation) => {
            AnnotationRect({
              annotation: ann,
              isSelected: ann.id === this.selectedAnnotationID,
              themeMode: this.themeMode,
              onTap: (a: PdfAnnotation) => {
                if (this.onAnnotationTap) { this.onAnnotationTap(a); }
              },
            })
          },
          (ann: PdfAnnotation): string => ann.id
        )
      }
      .width(this.pageWidth)
      .height(this.pageHeight)
    }
    .width(this.pageWidth)
  }
}
