/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: elements/quickSearchTextbox.js — debounced quick search
 *
 * ***** END LICENSE BLOCK *****
 */

/**
 * Debounced search bar. Fires onSearch after 150ms idle.
 * Ref: quickSearchTextbox.js — setTimeout debounce pattern
 */
import { ZHColor, ZHMetric } from '../theme/ThemeConstants.ets';

@Component
export struct QuickSearchBar {
  @Prop placeholder: string = 'Search library…';
  @Link inputText: string;
  @StorageLink('zotero_theme') themeMode: string = 'light';
  onSearch?: (text: string) => void;
  onInput?: (text: string) => void;
  private timerID: number | null = null;

  build() {
    Row() {
      Text('⌕')
        .fontSize(18)
        .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
        .margin({ left: 10, right: 4 })

        TextInput({ placeholder: this.placeholder, text: this.inputText })
          .fontSize(14)
          .height(36)
          .layoutWeight(1)
          .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
          .backgroundColor(ZHColor.TRANSPARENT)
          .border({ width: 0 })
          .onChange((value: string) => {
            this.inputText = value;
            if (this.onInput) { this.onInput(value); }
            this._debounce(value);
          })

      if (this.inputText.length > 0) {
        Text('✕')
          .fontSize(14).fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
          .width(32)
          .textAlign(TextAlign.Center)
          .onClick(() => {
            this.inputText = '';
            if (this.onSearch) { this.onSearch(''); }
          })
      }
    }
    .width('100%')
    .height(38)
    .backgroundColor(this.themeMode === 'dark' ? '#242A33' : ZHColor.SURFACE_ALT)
    .borderRadius(ZHMetric.RADIUS_MEDIUM)
    .border({ width: 1, color: this.themeMode === 'dark' ? '#303846' : ZHColor.BORDER_SOFT })
  }

  /** Debounce search to avoid excessive re-renders. Ref: 150ms timeout. */
  private _debounce(value: string): void {
    if (this.timerID !== null) {
      clearTimeout(this.timerID);
    }
    this.timerID = setTimeout(() => {
      if (this.onSearch) { this.onSearch(value); }
      this.timerID = null;
    }, 150);
  }

  clear(): void {
    this.inputText = '';
    if (this.onSearch) { this.onSearch(''); }
  }
}
