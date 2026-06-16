/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Zotero-style import/export workflow page.
 *
 * ***** END LICENSE BLOCK *****
 */

import { router } from '@kit.ArkUI';
import { LibraryRepository } from '../database/LibraryRepository.ets';
import { ImportFormat, ImportResult, ImportService } from '../import/ImportService.ets';
import { ExportFormat, ExportService } from '../import/ExportService.ets';
import { QuickCopy } from '../clipboard/QuickCopy.ets';
import { ItemModel } from '../model/ItemModel.ets';
import { ZHColor } from '../theme/ThemeConstants.ets';
import { Preferences, PrefKey } from '../utils/Preferences.ets';

interface FormatChoice {
  id: string;
  label: string;
}

const IMPORT_FORMATS: FormatChoice[] = [
  { id: 'auto', label: 'Auto' },
  { id: 'bibtex', label: 'BibTeX' },
  { id: 'ris', label: 'RIS' },
  { id: 'csljson', label: 'CSL JSON' },
];

const EXPORT_FORMATS: FormatChoice[] = [
  { id: 'bibtex', label: 'BibTeX' },
  { id: 'ris', label: 'RIS' },
  { id: 'csljson', label: 'CSL JSON' },
];

@Entry
@Component
struct ImportExportPage {
  @State mode: 'import' | 'export' = 'import';
  @State importFormat: ImportFormat = 'auto';
  @State exportFormat: ExportFormat = 'bibtex';
  @State inputText: string = '';
  @State outputText: string = '';
  @State statusText: string = '';
  @State selectedCount: number = 0;
  @StorageLink('zotero_theme') themeMode: string = 'light';
  private collectionKey: string = '';
  private itemKeys: string[] = [];
  private exportItems: ItemModel[] = [];

  aboutToAppear(): void {
    let params = router.getParams() as Record<string, Object>;
    let modeParam = (params?.['mode'] as string) ?? 'import';
    this.mode = modeParam === 'export' ? 'export' : 'import';
    this.collectionKey = (params?.['collectionKey'] as string) ?? '';
    let itemKeyParam = (params?.['itemKeys'] as string) ?? '';
    this.itemKeys = itemKeyParam.length > 0 ? itemKeyParam.split(',') : [];
    Preferences.init(getContext(this).getApplicationContext()).then(() => {
      return Preferences.getString(PrefKey.DEFAULT_EXPORT_FORMAT);
    }).then((value: string) => {
      if (this.mode === 'export') {
        let normalized = value.toLowerCase();
        if (normalized === 'bibtex' || normalized === 'ris' || normalized === 'csljson') {
          this.exportFormat = normalized as ExportFormat;
        }
        this.loadExportItems();
      }
    }).catch((_err: Error) => {
      if (this.mode === 'export') {
        this.loadExportItems();
      }
    });
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
        Text(this.mode === 'import' ? 'Import Items' : 'Export Items')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
          .layoutWeight(1)
        Button(this.mode === 'import' ? 'Export' : 'Import')
          .fontSize(12)
          .height(32)
          .backgroundColor(this.themeMode === 'dark' ? '#242A33' : ZHColor.SURFACE_ALT)
          .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
          .onClick(() => {
            this.mode = this.mode === 'import' ? 'export' : 'import';
            if (this.mode === 'export') {
              this.loadExportItems();
            }
          })
      }
      .width('100%')
      .height(52)
      .padding({ left: 8, right: 12 })
      .border({ width: { bottom: 1 }, color: this.themeMode === 'dark' ? '#303846' : ZHColor.BORDER })

      if (this.mode === 'import') {
        Column() {
          Row() {
            ForEach(IMPORT_FORMATS, (choice: FormatChoice) => {
              Button(choice.label)
                .fontSize(12)
                .height(32)
                .backgroundColor(this.importFormat === choice.id ? ZHColor.BRAND : (this.themeMode === 'dark' ? '#242A33' : ZHColor.SURFACE_ALT))
                .fontColor(this.importFormat === choice.id ? ZHColor.TEXT_INVERSE : (this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT))
                .margin({ right: 6 })
                .onClick(() => { this.importFormat = choice.id as ImportFormat; })
            }, (choice: FormatChoice): string => choice.id)
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 12, bottom: 8 })

          TextArea({ text: this.inputText, placeholder: 'Paste BibTeX, RIS, or CSL JSON here' })
            .fontSize(13)
            .height(260)
            .margin({ left: 12, right: 12 })
            .backgroundColor(this.themeMode === 'dark' ? '#11151B' : ZHColor.SURFACE)
            .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
            .onChange((value: string) => { this.inputText = value; })

          Row() {
            Button('Read Clipboard')
              .fontSize(12)
              .height(34)
              .backgroundColor(this.themeMode === 'dark' ? '#242A33' : ZHColor.SURFACE_ALT)
              .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
              .onClick(() => { this.readClipboard(); })
            Button('Import')
              .fontSize(12)
              .height(34)
              .margin({ left: 8 })
              .backgroundColor(ZHColor.BRAND)
              .fontColor(ZHColor.TEXT_INVERSE)
              .onClick(() => { this.importInput(); })
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 10 })
        }
        .layoutWeight(1)
      } else {
        Column() {
          Row() {
            Text(`${this.selectedCount} selected item${this.selectedCount === 1 ? '' : 's'}`)
              .fontSize(13)
              .fontColor(ZHColor.TEXT_MUTED)
              .layoutWeight(1)
            ForEach(EXPORT_FORMATS, (choice: FormatChoice) => {
              Button(choice.label)
                .fontSize(12)
                .height(32)
                .backgroundColor(this.exportFormat === choice.id ? ZHColor.BRAND : (this.themeMode === 'dark' ? '#242A33' : ZHColor.SURFACE_ALT))
                .fontColor(this.exportFormat === choice.id ? ZHColor.TEXT_INVERSE : (this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT))
                .margin({ left: 6 })
                .onClick(() => {
                  this.exportFormat = choice.id as ExportFormat;
                  this.refreshExportOutput();
                })
            }, (choice: FormatChoice): string => choice.id)
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 12, bottom: 8 })

          TextArea({ text: this.outputText, placeholder: 'Export preview' })
            .fontSize(13)
            .height(300)
            .margin({ left: 12, right: 12 })
            .backgroundColor(this.themeMode === 'dark' ? '#11151B' : ZHColor.SURFACE)
            .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
            .onChange((value: string) => { this.outputText = value; })

          Row() {
            Button('Refresh')
              .fontSize(12)
              .height(34)
              .backgroundColor(this.themeMode === 'dark' ? '#242A33' : ZHColor.SURFACE_ALT)
              .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
              .onClick(() => { this.refreshExportOutput(); })
            Button('Copy Export')
              .fontSize(12)
              .height(34)
              .margin({ left: 8 })
              .backgroundColor(ZHColor.BRAND)
              .fontColor(ZHColor.TEXT_INVERSE)
              .onClick(() => { this.copyExport(); })
          }
          .width('100%')
          .padding({ left: 12, right: 12, top: 10 })
        }
        .layoutWeight(1)
      }

      Text(this.statusText)
        .fontSize(12)
        .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 10 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeMode === 'dark' ? '#11151B' : ZHColor.SURFACE)
  }

  private readClipboard(): void {
    QuickCopy.readText().then((text: string) => {
      this.inputText = text;
      this.statusText = text.length > 0 ? 'Clipboard text loaded' : 'Clipboard is empty';
    }).catch((_err: Error) => {
      this.statusText = 'Could not read clipboard';
    });
  }

  private importInput(): void {
    let result: ImportResult = ImportService.importText(this.inputText, this.importFormat);
    if (result.items.length === 0) {
      this.statusText = result.warnings.length > 0 ? result.warnings.join('; ') : 'No items found';
      return;
    }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.importItems(result.items, this.collectionKey.length > 0 ? this.collectionKey : null);
    }).then((keys: string[]) => {
      this.statusText = `Imported ${keys.length} item${keys.length === 1 ? '' : 's'} as ${result.format}`;
      repo.close();
    }).catch((_err: Error) => {
      this.statusText = 'Import failed';
      repo.close();
    });
  }

  private loadExportItems(): void {
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      if (this.itemKeys.length > 0) {
        return repo.getItemsByKeys(this.itemKeys);
      }
      return repo.listItems(this.collectionKey.length > 0 ? this.collectionKey : null, '');
    }).then((items: ItemModel[]) => {
      this.exportItems = items;
      this.selectedCount = items.length;
      this.refreshExportOutput();
      repo.close();
    }).catch((_err: Error) => {
      this.exportItems = [];
      this.selectedCount = 0;
      this.statusText = 'Could not load selected items';
      repo.close();
    });
  }

  private refreshExportOutput(): void {
    if (this.exportItems.length === 0) {
      this.outputText = '';
      this.statusText = 'Select one or more items before exporting';
      return;
    }
    this.outputText = ExportService.exportItems(this.exportItems, this.exportFormat);
    this.statusText = `Prepared ${this.exportItems.length} item${this.exportItems.length === 1 ? '' : 's'} as ${this.exportFormat}`;
  }

  private copyExport(): void {
    QuickCopy.copyText(this.outputText).then(() => {
      this.statusText = 'Export copied to clipboard';
    }).catch((_err: Error) => {
      this.statusText = 'Could not copy export';
    });
  }
}
