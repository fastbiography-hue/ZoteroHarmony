/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: reader.xhtml + zoteroPane.js reader tab handling
 *
 * Full reader page: toolbar + PDF pages + annotation sidebar
 *
 * ***** END LICENSE BLOCK *****
 */

import { router } from '@kit.ArkUI';
import { readerManager, ReaderStateCallback } from './ReaderManager.ets';
import { PdfAnnotation, ReaderState } from './ReaderTypes.ets';
import { ReaderToolbar, ReaderTool } from './ReaderToolbar.ets';
import { PdfPageView } from './PdfPageView.ets';
import { LibraryRepository } from '../database/LibraryRepository.ets';

/**
 * Full PDF reader page.
 *
 * Layout:
 *   ┌─────────────────────┐
 *   │    ReaderToolbar     │
 *   ├─────────────────────┤
 *   │                     │
 *   │   PdfPageView(s)    │  ← scrollable
 *   │                     │
 *   ├─────────────────────┤
 *   │ Annotation sidebar  │  ← collapsible
 *   └─────────────────────┘
 */
@Entry
@Component
struct ReaderPage {
  @State readerState: ReaderState | null = null;
  @State selectedTool: ReaderTool = 'pan';
  @State selectedColor: string = '#FFD700';
  @State selectedAnnotationID: string = '';
  @State selectedAnnotationComment: string = '';
  @State selectedAnnotationColor: string = '';
  @State sidebarOpen: boolean = false;
  @StorageLink('zotero_theme') themeMode: string = 'light';
  private itemKey: string = '';
  private readerCallback: ReaderStateCallback | null = null;

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, Object>;
    this.itemKey = (params?.['itemKey'] as string) ?? '';
    this.readerState = readerManager.get(this.itemKey);
    if (this.readerState) {
      this.readerCallback = (state: ReaderState) => {
        this.readerState = state;
      };
      readerManager.subscribe(this.itemKey, this.readerCallback);
      this.loadAnnotations();
    }
  }

  aboutToDisappear(): void {
    if (this.itemKey && this.readerCallback) {
      readerManager.unsubscribe(this.itemKey, this.readerCallback);
    }
  }

  build() {
    Column() {
      // Toolbar
      if (this.readerState) {
        ReaderToolbar({
          selectedTool: $selectedTool,
          selectedColor: $selectedColor,
          currentPage: this.readerState.currentPage,
          totalPages: this.readerState.totalPages,
          docTitle: this.readerState.title,
          onPageChange: (page: number) => {
            readerManager.goToPage(this.itemKey, page);
          },
          onClose: () => {
            readerManager.close(this.itemKey);
            router.back();
          },
        })
        Row() {
          Button('Add Mark')
            .fontSize(12)
            .height(30)
            .enabled(this.selectedTool === 'highlight' || this.selectedTool === 'underline' || this.selectedTool === 'note')
            .onClick(() => { this.addAnnotationForCurrentTool(); })
          Text(this.selectedTool === 'pan' || this.selectedTool === 'select' ? 'Choose highlight, underline, or note' : `Ready: ${this.selectedTool}`)
            .fontSize(12)
            .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : '#666666')
            .margin({ left: 8 })
        }
        .width('100%')
        .height(36)
        .padding({ left: 12, right: 12 })
        .backgroundColor(this.themeMode === 'dark' ? '#171B22' : '#FFFFFF')
      }

      // Main content
      if (this.readerState) {
        Stack() {
          // PDF page
          Scroll() {
            PdfPageView({
              pageIndex: this.readerState.currentPage - 1,
              filePath: this.readerState.filePath,
              annotations: this.readerState.annotations,
              selectedAnnotationID: this.selectedAnnotationID,
              onAnnotationTap: (ann: PdfAnnotation) => {
                this.selectedAnnotationID = ann.id;
                this.selectedAnnotationComment = ann.comment ?? 'No comment';
                this.selectedAnnotationColor = ann.color;
                if (ann.comment) {
                  this.sidebarOpen = true;
                }
              },
            })
            .margin({ top: 8 })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
          .edgeEffect(EdgeEffect.Spring)

          // Annotation note sidebar (right side, when open)
          if (this.sidebarOpen) {
            this._annotationSidebar()
          }
        }
        .layoutWeight(1)
      } else {
        Column() {
          Text('No reader state loaded')
            .fontSize(16).fontColor(this.themeMode === 'dark' ? '#AAB4C2' : '#999')
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%').height('100%')
    .backgroundColor(this.themeMode === 'dark' ? '#11151B' : '#FFFFFF')
  }

  @Builder
  _annotationSidebar() {
    Column() {
      Row() {
        Text('Annotation').fontSize(14).fontWeight(FontWeight.Medium).layoutWeight(1)
        Button('✕').fontSize(14).width(32).height(32)
          .backgroundColor('#00000000')
          .onClick(() => { this.sidebarOpen = false; })
      }
      .width('100%').padding(8)

      if (this.selectedAnnotationID.length > 0) {
        TextArea({ text: this.selectedAnnotationComment, placeholder: 'Add annotation note…' })
          .fontSize(13)
          .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : '#333333')
          .height(120)
          .margin({ left: 8, right: 8, bottom: 8 })
          .onChange((value: string) => { this.selectedAnnotationComment = value; })
        Text(`Color: ${this.selectedAnnotationColor}`)
          .fontSize(11).fontColor(this.themeMode === 'dark' ? '#AAB4C2' : '#999').padding({ left: 8, bottom: 8 })
        Row() {
          Button('Save')
            .fontSize(12)
            .height(30)
            .onClick(() => { this.saveSelectedAnnotationComment(); })
          Button('Delete')
            .fontSize(12)
            .height(30)
            .margin({ left: 8 })
            .backgroundColor('#FFF0F0')
            .fontColor('#B4282E')
            .onClick(() => { this.deleteSelectedAnnotation(); })
        }
        .padding({ left: 8, right: 8 })
      }
    }
    .width(200)
    .height('100%')
    .backgroundColor(this.themeMode === 'dark' ? '#171B22' : '#FFFFFF')
    .border({ width: { left: 1 }, color: this.themeMode === 'dark' ? '#303846' : '#E0E0E0' })
    .position({ x: 0, y: 0 })
    .offset({ x: 'calc(100% - 200vp)', y: 0 })
  }

  private loadAnnotations(): void {
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.listAnnotations(this.itemKey);
    }).then((annotations: PdfAnnotation[]) => {
      readerManager.setAnnotations(this.itemKey, annotations);
      repo.close();
    }).catch((_err: Error) => {
      repo.close();
    });
  }

  private addAnnotationForCurrentTool(): void {
    if (!this.readerState) {
      return;
    }
    if (this.selectedTool !== 'highlight' && this.selectedTool !== 'underline' && this.selectedTool !== 'note') {
      return;
    }
    let now = `${new Date().toISOString()}`;
    let ann: PdfAnnotation = {
      id: `${this.itemKey}-${Date.now()}`,
      type: this.selectedTool === 'underline' ? 'underline' : (this.selectedTool === 'note' ? 'note' : 'highlight'),
      pageIndex: this.readerState.currentPage - 1,
      position: this.selectedTool === 'note' ?
        { x: 0.78, y: 0.12, width: 0.08, height: 0.08 } :
        { x: 0.16, y: 0.22, width: 0.58, height: 0.05 },
      color: this.selectedColor,
      text: this.selectedTool === 'note' ? '' : 'Selected text',
      comment: '',
      authorName: 'Me',
      sortIndex: `${this.readerState.currentPage}-${Date.now()}`,
      dateModified: now,
    };
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.saveAnnotation(this.itemKey, ann);
    }).then(() => {
      readerManager.addAnnotation(this.itemKey, ann);
      this.selectedAnnotationID = ann.id;
      this.selectedAnnotationComment = '';
      this.selectedAnnotationColor = ann.color;
      this.sidebarOpen = true;
      repo.close();
    }).catch((_err: Error) => {
      repo.close();
    });
  }

  private saveSelectedAnnotationComment(): void {
    if (!this.readerState || this.selectedAnnotationID.length === 0) {
      return;
    }
    let modified = `${new Date().toISOString()}`;
    readerManager.updateAnnotation(this.itemKey, this.selectedAnnotationID, {
      comment: this.selectedAnnotationComment,
      dateModified: modified,
    });
    let state = readerManager.get(this.itemKey);
    if (!state) {
      return;
    }
    let annotations = state.annotations.filter((ann: PdfAnnotation): boolean => ann.id === this.selectedAnnotationID);
    if (annotations.length === 0) {
      return;
    }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.saveAnnotation(this.itemKey, annotations[0]);
    }).then(() => {
      repo.close();
    }).catch((_err: Error) => {
      repo.close();
    });
  }

  private deleteSelectedAnnotation(): void {
    if (this.selectedAnnotationID.length === 0) {
      return;
    }
    let annID = this.selectedAnnotationID;
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.deleteAnnotation(this.itemKey, annID);
    }).then(() => {
      readerManager.removeAnnotation(this.itemKey, annID);
      this.selectedAnnotationID = '';
      this.selectedAnnotationComment = '';
      this.sidebarOpen = false;
      repo.close();
    }).catch((_err: Error) => {
      repo.close();
    });
  }
}
