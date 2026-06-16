/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: zoteroPane.xhtml — integrated search experience
 *
 * ***** END LICENSE BLOCK *****
 */

import { router } from '@kit.ArkUI';
import { ItemModel } from '../model/ItemModel.ets';
import { SearchEngine, SearchCondition, JoinMode } from '../search/SearchEngine.ets';
import { semanticSplitter } from '../search/FulltextIndex.ets';
import { AdvancedSearchPane } from '../ui/AdvancedSearchPane.ets';
import { SearchResultsList, SearchResultItem } from '../ui/SearchResultsList.ets';
import { QuickSearchBar } from '../ui/QuickSearchBar.ets';
import { SearchSuggestions } from '../ui/SearchSuggestions.ets';
import { AppStore } from '../utils/AppStore.ets';
import { LibraryRepository, SavedSearchConditionData } from '../database/LibraryRepository.ets';

/**
 * Search page — quick search bar + advanced condition builder + results list.
 *
 * Navigation: MainPage → tap search → SearchPage (or embedded modal)
 */
@Entry
@Component
struct SearchPage {
  @State conditions: SearchCondition[] = [];
  @State results: SearchResultItem[] = [];
  @State mode: 'quick' | 'advanced' = 'quick';
  @State joinMode: JoinMode = 'all';
  @State queryText: string = '';
  @State suggestions: string[] = [];
  @StorageLink('zotero_theme') themeMode: string = 'light';
  private engine: SearchEngine = new SearchEngine();
  private allItems: ItemModel[] = [];  // loaded from DB/API

  aboutToAppear(): void {
    this._loadItems();
  }

  build() {
    Column() {
      // Search bar
      Row() {
        Button('←').fontSize(20).width(40).height(40)
          .backgroundColor('#00000000')
          .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : '#666666')
          .onClick(() => { router.back(); })

        QuickSearchBar({
          inputText: $queryText,
          placeholder: 'Search title, creator, year, tag…',
          onInput: (text: string) => {
            this.queryText = text;
            this._updateSuggestions(text);
          },
          onSearch: (text: string) => {
            this._quickSearch(text);
          },
        })
        .layoutWeight(1)
      }
      .width('100%').padding({ left: 4, right: 8, top: 4 })
      .border({ width: { bottom: 1 }, color: this.themeMode === 'dark' ? '#303846' : '#E0E0E0' })

      if (this.mode === 'quick' && this.suggestions.length > 0) {
        SearchSuggestions({
          suggestions: this.suggestions,
          onPick: (value: string) => {
            this.queryText = value;
            this._quickSearch(value);
          },
        })
      }

      // Mode toggle
      Row() {
        Button('Quick').fontSize(13).height(32)
          .backgroundColor(this.mode === 'quick' ? '#CC3333' : (this.themeMode === 'dark' ? '#242A33' : '#F5F5F5'))
          .fontColor(this.mode === 'quick' ? '#FFF' : (this.themeMode === 'dark' ? '#F4F6FA' : '#666'))
          .onClick(() => { this.mode = 'quick'; })

        Button('Advanced').fontSize(13).height(32)
          .backgroundColor(this.mode === 'advanced' ? '#CC3333' : (this.themeMode === 'dark' ? '#242A33' : '#F5F5F5'))
          .fontColor(this.mode === 'advanced' ? '#FFF' : (this.themeMode === 'dark' ? '#F4F6FA' : '#666'))
          .margin({ left: 6 })
          .onClick(() => { this.mode = 'advanced'; })
      }
      .width('100%').padding({ left: 12, top: 6, bottom: 4 })

      // Content
      if (this.mode === 'advanced') {
        AdvancedSearchPane({
          conditions: $conditions,
          joinMode: this.joinMode,
          onSearch: (conds: SearchCondition[], mode: JoinMode) => {
            this._advancedSearch(conds, mode);
          },
          onSave: (name: string, conds: SearchCondition[], mode: JoinMode) => {
            this._saveSearch(name, conds, mode);
          },
        })
        .layoutWeight(1)
      } else {
        // Quick search results
        SearchResultsList({
          results: $results,
          emptyMessage: this.results.length === 0 ? 'Type to search your library' : '',
          onItemOpen: (item: ItemModel) => {
            AppStore.selectedItemKey = item.key;
            router.back();
          },
        })
        .layoutWeight(1)
      }
    }
    .width('100%').height('100%').backgroundColor(this.themeMode === 'dark' ? '#11151B' : '#FFFFFF')
  }

  // ==================================================================
  // Search methods
  // ==================================================================

  private _quickSearch(text: string): void {
    if (!text.trim()) { this.results = []; return; }
    this.queryText = text;
    this._updateSuggestions(text);

    this.engine.clearConditions();
    // Split quoted/word tokens
    let tokens = semanticSplitter(text);

    // Quick search = title + creator + year + tag (OR per token)
    this.engine.setJoinMode('any');
    for (let i = 0; i < tokens.length; i++) {
      let t = tokens[i];
      // Search across multiple fields
      this.engine.addCondition('title', 'contains', t, false);
      this.engine.addCondition('creator', 'contains', t, false);
      this.engine.addCondition('tag', 'contains', t, false);
      // Try year match
      if (/^\d{4}$/.test(t)) {
        this.engine.addCondition('year', 'is', t, false);
      }
    }

    let filtered = this.engine.filter(this.allItems);
    this.results = filtered.map((item: ItemModel): SearchResultItem => ({
      item,
      matchField: 'title',
      matchPreview: item.itemData.get('title') ?? '',
    }));
  }

  private _loadItems(): void {
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.listItems(null, '');
    }).then((items: ItemModel[]) => {
      this.allItems = items;
      repo.close();
    }).catch((_err: Error) => {
      this.allItems = [];
      repo.close();
    });
  }

  private _saveSearch(name: string, conds: SearchCondition[], mode: JoinMode): void {
    let conditionData: SavedSearchConditionData[] = [];
    conditionData.push({
      condition: 'joinMode',
      operator: 'is',
      value: mode,
      required: true,
    });
    for (let i = 0; i < conds.length; i++) {
      conditionData.push({
        condition: conds[i].condition,
        operator: conds[i].operator,
        value: conds[i].value,
        required: conds[i].required,
      });
    }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.createSavedSearch(name, conditionData);
    }).then((_key: string) => {
      repo.close();
    }).catch((_err: Error) => {
      repo.close();
    });
  }

  private _advancedSearch(conds: SearchCondition[], mode: JoinMode): void {
    this.engine.clearConditions();
    this.engine.setJoinMode(mode);
    for (let i = 0; i < conds.length; i++) {
      let c = conds[i];
      if (c.value) {
        this.engine.addCondition(c.condition, c.operator, c.value, c.required);
      }
    }
    let filtered = this.engine.filter(this.allItems);
    this.results = filtered.map((item: ItemModel): SearchResultItem => ({
      item,
      matchField: conds[0]?.condition ?? 'title',
      matchPreview: item.itemData.get(conds[0]?.condition ?? 'title') ?? '',
    }));
  }

  private _updateSuggestions(text: string): void {
    let trimmed = text.trim().toLowerCase();
    if (trimmed.length === 0) {
      this.suggestions = [];
      return;
    }

    let prefix = trimmed.split(/\s+/).pop() ?? '';
    if (prefix.length === 0) {
      this.suggestions = [];
      return;
    }

    let seen: Set<string> = new Set<string>();
    let suggestions: string[] = [];
    for (let i = 0; i < this.allItems.length; i++) {
      let item = this.allItems[i];
      this._collectSuggestion(seen, suggestions, item.itemData.get('title') ?? '', prefix);
      this._collectSuggestion(seen, suggestions, item.itemData.get('creator') ?? '', prefix);
      this._collectSuggestion(seen, suggestions, item.itemData.get('publisher') ?? '', prefix);
      this._collectSuggestion(seen, suggestions, item.itemData.get('date') ?? '', prefix);
      for (let j = 0; j < item.tags.length; j++) {
        this._collectSuggestion(seen, suggestions, item.tags[j].tag, prefix);
      }
      if (suggestions.length >= 8) {
        break;
      }
    }
    this.suggestions = suggestions;
  }

  private _collectSuggestion(seen: Set<string>, suggestions: string[], value: string, prefix: string): void {
    if (value.length === 0) {
      return;
    }
    let words = value.split(/[^A-Za-z0-9:_-]+/);
    for (let i = 0; i < words.length; i++) {
      let token = words[i].trim();
      if (token.length === 0 || !token.toLowerCase().startsWith(prefix)) {
        continue;
      }
      let normalized = token.toLowerCase();
      if (!seen.has(normalized)) {
        seen.add(normalized);
        suggestions.push(token);
      }
      if (suggestions.length >= 8) {
        return;
      }
    }
  }
}
