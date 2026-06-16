/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: elements/advancedSearchPane.js — advanced search condition builder
 *
 * ***** END LICENSE BLOCK *****
 */

import { SearchEngine, SearchCondition, JoinMode } from '../search/SearchEngine.ets';

/** Available search fields. */
const SEARCH_FIELDS: string[] = [
  'title', 'creator', 'year', 'tag',
  'DOI', 'ISBN', 'ISSN', 'itemType',
  'publisher', 'place', 'abstractNote', 'extra',
];

/** Available operators. */
const OPERATORS: string[] = [
  'contains', 'is', 'isNot', 'beginsWith', 'isBefore', 'isAfter',
];

/** One condition row in the builder. */
@Component
struct ConditionRow {
  @Prop cond: SearchCondition = { id: 0, condition: 'title', operator: 'contains', value: '', required: false };
  onUpdate?: (id: number, field: string, op: string, value: string) => void;
  onRemove?: (id: number) => void;
  @StorageLink('zotero_theme') themeMode: string = 'light';

  build() {
    Row() {
      // Field selector
      Text(this.cond.condition)
        .fontSize(13).fontColor(this.themeMode === 'dark' ? '#F4F6FA' : '#333')
        .width(90).padding(4)
        .backgroundColor(this.themeMode === 'dark' ? '#242A33' : '#F5F5F5').borderRadius(4)
        .textAlign(TextAlign.Center)

      // Operator
      Text(this.cond.operator)
        .fontSize(13).fontColor(this.themeMode === 'dark' ? '#AAB4C2' : '#666')
        .width(90).padding(4)
        .backgroundColor(this.themeMode === 'dark' ? '#242A33' : '#F5F5F5').borderRadius(4)
        .textAlign(TextAlign.Center)
        .margin({ left: 6 })

      // Value input
      TextInput({ text: this.cond.value, placeholder: 'value…' })
        .fontSize(14).height(36).layoutWeight(1)
        .margin({ left: 6 })
        .onChange((v: string) => {
          if (this.onUpdate) { this.onUpdate(this.cond.id, this.cond.condition, this.cond.operator, v); }
        })

      Button('✕').fontSize(14).width(32).height(36)
        .backgroundColor('#00000000').fontColor('#999')
        .onClick(() => { if (this.onRemove) { this.onRemove(this.cond.id); } })
    }
    .width('100%').padding({ left: 12, right: 4, top: 4, bottom: 4 })
  }
}

/**
 * Advanced search condition builder.
 *
 * Replaces: elements/advancedSearchPane.js
 */
@Component
export struct AdvancedSearchPane {
  @Link conditions: SearchCondition[];
  @State joinMode: JoinMode = 'all';
  @State searchName: string = '';
  @StorageLink('zotero_theme') themeMode: string = 'light';
  onSearch?: (conditions: SearchCondition[], mode: JoinMode) => void;
  onSave?: (name: string, conditions: SearchCondition[], mode: JoinMode) => void;

  build() {
    Column() {
      // Header: name + mode
      Row() {
        TextInput({ placeholder: 'Search name (optional)', text: this.searchName })
          .fontSize(15).height(36).layoutWeight(1)
          .onChange((v: string) => { this.searchName = v; })

        Row() {
          Text(this.joinMode === 'all' ? 'AND' : 'OR')
            .fontSize(13).fontColor('#FFF').fontWeight(FontWeight.Bold)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('#CC3333').borderRadius(4)
        }
        .onClick(() => {
          this.joinMode = this.joinMode === 'all' ? 'any' : 'all';
        })
        .margin({ left: 8 })
      }
      .width('100%').padding({ left: 12, right: 12, top: 8, bottom: 4 })

      // Condition rows
      Scroll() {
        Column() {
          ForEach(this.conditions, (cond: SearchCondition) => {
            ConditionRow({
              cond: cond,
              onUpdate: (id: number, field: string, op: string, value: string) => {
                let copy: SearchCondition[] = [];
                for (let k = 0; k < this.conditions.length; k++) { copy.push(this.conditions[k]); }
                let idx = copy.findIndex((c: SearchCondition) => c.id === id);
                if (idx >= 0) {
                  copy[idx] = {
                    id: copy[idx].id, condition: field, operator: op,
                    value: value, required: copy[idx].required,
                  };
                  this.conditions = copy;
                }
              },
              onRemove: (id: number) => {
                this.conditions = this.conditions.filter((c: SearchCondition) => c.id !== id);
              },
            })
          }, (cond: SearchCondition): string => `cond-${cond.id}`)
        }
        .width('100%')
      }
      .layoutWeight(1)

      // Action row
      Row() {
        Button('+ Add Condition')
          .fontSize(13).height(36)
          .onClick(() => {
            let maxId = 0;
            for (let j = 0; j < this.conditions.length; j++) {
              if (this.conditions[j].id > maxId) { maxId = this.conditions[j].id; }
            }
            let id = maxId + 1;
            this.conditions = [...this.conditions, {
              id, condition: 'title', operator: 'contains', value: '', required: false,
            }];
          })

        Blank()

        if (this.onSave) {
          Button('Save').fontSize(13).height(36).margin({ right: 6 })
            .onClick(() => {
              if (this.onSave) { this.onSave(this.searchName, this.conditions, this.joinMode); }
            })
        }

        Button('Search').fontSize(13).height(36)
          .backgroundColor('#CC3333')
          .onClick(() => {
            if (this.onSearch) { this.onSearch(this.conditions, this.joinMode); }
          })
      }
      .width('100%').padding({ left: 12, right: 12, top: 8, bottom: 8 })
      .border({ width: { top: 1 }, color: this.themeMode === 'dark' ? '#252C38' : '#E0E0E0' })
    }
    .width('100%').height('100%')
    .backgroundColor(this.themeMode === 'dark' ? '#11151B' : '#FFFFFF')
  }
}
