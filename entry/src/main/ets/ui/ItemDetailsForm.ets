/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: elements/itemDetails.js — main item detail form
 *
 * Draft-based edit with explicit Save/Reset.
 * Draft rebuilds when itemKey changes.
 *
 * ***** END LICENSE BLOCK *****
 */

import { ItemModel } from '../model/ItemModel.ets';
import { ItemType, CSLField, ZoteroCreator, ZoteroTag } from '../model/ItemTypes.ets';
import { ItemTypeDropdown } from './ItemTypeDropdown.ets';
import { FieldEditor } from './FieldEditor.ets';
import { CreatorEditor } from './CreatorEditor.ets';
import { TagChipEditor } from './TagChipEditor.ets';
import { LibraryRepository } from '../database/LibraryRepository.ets';
import { ZHColor } from '../theme/ThemeConstants.ets';

interface FieldDraft {
  oldValue: string;
  newValue: string;
  dirty: boolean;
}

/**
 * Main item detail form — draft → explicit Save → DB + syncQueue.
 * Ref: elements/itemDetails.js
 */
@Component
export struct ItemDetailsForm {
  @Prop item: ItemModel = new ItemModel();
  /** Triggers draft rebuild when switching to a different item. */
  @Watch('_onItemSwitch')
  @Prop itemKey: string = '';
  /** Triggers refresh when the item is updated externally (e.g. after save). */
  @Prop itemRevision: number = 0;
  @State itemType: string = 'journalArticle';
  @State draftFields: Map<string, FieldDraft> = new Map();
  @State creators: ZoteroCreator[] = [];
  @State initialCreatorsJson: string = '';
  @State tags: ZoteroTag[] = [];
  @State initialTagsJson: string = '';
  @State readOnly: boolean = false;
  @State isSaving: boolean = false;
  @State saveStatus: 'idle' | 'dirty' | 'success' | 'error' = 'idle';
  @State saveMessage: string = '';
  @State isDirty: boolean = false;
  onItemSaved?: () => void;

  aboutToAppear(): void {
    this._resetDraft();
  }

  /** Rebuild draft when the selected item changes. */
  private _onItemSwitch(): void {
    this._resetDraft();
  }

  /** Rebuild draft from current item. */
  private _resetDraft(): void {
    this.itemType = this.item.itemData.get('itemType') ?? this.item.itemTypeName ?? 'journalArticle';
    this.creators = [...this.item.creators];
    this.initialCreatorsJson = creatorsToJson(this.creators);
    this.tags = [...this.item.tags];
    this.initialTagsJson = tagsToJson(this.tags);
    let fresh = new Map<string, FieldDraft>();
    this.item.itemData.forEach((value: string, key: string) => {
      if (key === 'itemType' || key === 'creator' || key === 'note') { return; }
      fresh.set(key, { oldValue: value, newValue: value, dirty: false });
    });
    let common = ['title', 'abstractNote', 'date', 'DOI', 'ISBN', 'ISSN', 'url',
      'publicationTitle', 'publisher', 'place', 'pages', 'volume', 'issue',
      'language', 'shortTitle', 'extra'];
    for (let i = 0; i < common.length; i++) {
      if (!fresh.has(common[i])) {
        fresh.set(common[i], { oldValue: '', newValue: '', dirty: false });
      }
    }
    this.draftFields = fresh;
    this.isDirty = false;
    this.saveStatus = 'idle';
    this.saveMessage = '';
    this.isSaving = false;
  }

  build() {
    Column() {
      // ---- Save / Reset bar ----
      Row() {
        if (this.saveStatus === 'success') {
          Text(this.saveMessage)
            .fontSize(11).fontColor('#2E7D32').layoutWeight(1)
        } else if (this.saveStatus === 'error') {
          Text(this.saveMessage)
            .fontSize(11).fontColor('#C62828').layoutWeight(1)
        } else if (this.saveStatus === 'dirty') {
          Text('Unsaved changes')
            .fontSize(11).fontColor(ZHColor.WARNING).layoutWeight(1)
        } else {
          Blank().layoutWeight(1)
        }
        Button('Reset').fontSize(11).height(26)
          .margin({ right: 6 })
          .enabled(this.isDirty)
          .backgroundColor(ZHColor.SURFACE_ALT)
          .fontColor(ZHColor.TEXT)
          .onClick(() => { this._resetDraft(); })
        Button('Save').fontSize(11).height(26)
          .enabled(this.isDirty && !this.isSaving)
          .backgroundColor(ZHColor.BRAND)
          .fontColor(ZHColor.TEXT_INVERSE)
          .onClick(() => { this._doSave(); })
      }
      .width('100%').padding({ left: 12, right: 12, top: 6, bottom: 6 })
      .backgroundColor(ZHColor.SURFACE_ALT)
      .border({ width: { bottom: 1 }, color: '#EEEEEE' })

      Scroll() {
        Column() {
          // Type selector
          ItemTypeDropdown({
            selectedType: this._toItemTypeEnum(this.itemType),
            disabled: this.readOnly,
            onChange: (newType: ItemType) => {
              let old = this.itemType;
              this.itemType = newType as string;
              if (old !== this.itemType) { this._markDirty(); }
            },
          })

          // ---- Information section ----
          this._sectionHeader('INFORMATION')

          FieldEditor({
            fieldName: 'title',
            fieldValue: this._draftVal('title'),
            onChange: (v: string) => { this._setField('title', v); },
          })
          FieldEditor({
            fieldName: 'abstractNote',
            fieldValue: this._draftVal('abstractNote'),
            multiline: true,
            onChange: (v: string) => { this._setField('abstractNote', v); },
          })

          // ---- Creators ----
          CreatorEditor({
            creators: $creators,
            readOnly: this.readOnly,
            onCreatorsChange: (creators: ZoteroCreator[]) => {
              this.creators = creators;
              if (!creatorsJsonEqual(this.initialCreatorsJson, creators)) {
                this._markDirty();
              } else {
                this._updateDirtyFlag();
              }
            },
          })

          // ---- Publication section ----
          this._sectionHeader('PUBLICATION')

          let pubFields = ['date', 'DOI', 'url', 'publicationTitle', 'volume', 'issue', 'pages'];
          for (let pi = 0; pi < pubFields.length; pi++) {
            FieldEditor({
              fieldName: pubFields[pi],
              fieldValue: this._draftVal(pubFields[pi]),
              onChange: (v: string) => { this._setField(pubFields[pi], v); },
            })
          }

          // ---- Extra section ----
          this._sectionHeader('EXTRA')
          FieldEditor({
            fieldName: 'extra',
            fieldValue: this._draftVal('extra'),
            multiline: true,
            onChange: (v: string) => { this._setField('extra', v); },
          })

          // ---- Tags ----
          TagChipEditor({
            tags: $tags,
            readOnly: this.readOnly,
            onTagsChange: (tags: ZoteroTag[]) => {
              this.tags = tags;
              if (!tagsJsonEqual(this.initialTagsJson, tags)) {
                this._markDirty();
              } else {
                this._updateDirtyFlag();
              }
            },
          })

          Blank().height(40)
        }
        .width('100%')
      }
    }
    .width('100%').height('100%')
  }

  @Builder
  _sectionHeader(title: string) {
    Text(title)
      .fontSize(12).fontColor('#999').fontWeight(FontWeight.Bold).width('100%')
      .padding({ left: 12, top: 12, bottom: 4 })
      .border({ width: { top: 1 }, color: '#EEEEEE' })
  }

  private _draftVal(fieldName: string): string {
    let d = this.draftFields.get(fieldName);
    return d ? d.newValue : '';
  }

  private _setField(fieldName: string, value: string): void {
    let existing = this.draftFields.get(fieldName);
    if (!existing) {
      this.draftFields.set(fieldName, { oldValue: '', newValue: value, dirty: true });
    } else {
      existing.newValue = value;
      existing.dirty = existing.newValue !== existing.oldValue;
    }
    this._updateDirtyFlag();
  }

  private _markDirty(): void {
    if (!this.isDirty) {
      this.isDirty = true;
      this.saveStatus = 'dirty';
    }
  }

  private _updateDirtyFlag(): void {
    let dirty = false;
    this.draftFields.forEach((fd: FieldDraft, _k: string) => {
      if (fd.dirty) { dirty = true; }
    });
    if (!dirty && this.itemType !== (this.item.itemData.get('itemType') ?? this.item.itemTypeName ?? 'journalArticle')) {
      dirty = true;
    }
    if (!dirty) {
      dirty = !creatorsJsonEqual(this.initialCreatorsJson, this.creators);
    }
    this.isDirty = dirty;
    if (dirty && this.saveStatus === 'idle') {
      this.saveStatus = 'dirty';
    }
  }

  private _toItemTypeEnum(s: string): ItemType {
    let map: Record<string, ItemType> = {
      'journalArticle': ItemType.JOURNAL_ARTICLE, 'book': ItemType.BOOK,
      'bookSection': ItemType.BOOK_SECTION, 'conferencePaper': ItemType.CONFERENCE_PAPER,
      'thesis': ItemType.THESIS, 'report': ItemType.REPORT, 'webpage': ItemType.WEBPAGE,
      'note': ItemType.NOTE, 'attachment': ItemType.ATTACHMENT,
      'annotation': ItemType.ANNOTATION,
    };
    return map[s] ?? ItemType.JOURNAL_ARTICLE;
  }

  /** Batch-save: type + changed fields + creators + tags → one flush. */
  private async _doSave(): Promise<void> {
    let itemKey = this.item.key ?? '';
    if (itemKey.length === 0) { return; }
    this.isSaving = true;
    this.saveStatus = 'dirty';
    try {
      let repo = new LibraryRepository();
      await repo.open(getContext(this).getApplicationContext());
      // 1. Type change
      let oldType = this.item.itemData.get('itemType') ?? this.item.itemTypeName ?? 'journalArticle';
      if (this.itemType !== oldType) {
        await repo.updateItemTypeByKey(itemKey, this.itemType);
      }
      // 2. Field changes
      let changedKeys: string[] = [];
      this.draftFields.forEach((fd: FieldDraft, fieldName: string) => {
        if (fd.dirty) { changedKeys.push(fieldName); }
      });
      for (let i = 0; i < changedKeys.length; i++) {
        let fd = this.draftFields.get(changedKeys[i])!;
        await repo.updateItemField(itemKey, changedKeys[i], fd.newValue);
      }
      // 3. Creators (only if changed)
      if (!creatorsJsonEqual(this.initialCreatorsJson, this.creators)) {
        await repo.updateItemCreatorsByKey(itemKey, this.creators);
      }
      // 4. Tags (only if changed)
      if (!tagsJsonEqual(this.initialTagsJson, this.tags)) {
        await repo.replaceItemTags(itemKey, this.tags);
      }
      await repo.close();

      // Update ItemModel + draft in place
      for (let i = 0; i < changedKeys.length; i++) {
        let fd = this.draftFields.get(changedKeys[i])!;
        this.item.itemData.set(changedKeys[i], fd.newValue);
        fd.oldValue = fd.newValue;
        fd.dirty = false;
      }
      this.item.itemData.set('itemType', this.itemType);
      this.item.itemTypeName = this.itemType;
      this.item.creators = [...this.creators];
      this.item.tags = [...this.tags];
      this.initialCreatorsJson = creatorsToJson(this.creators);
      this.initialTagsJson = tagsToJson(this.tags);
      this.isDirty = false;
      this.saveStatus = 'success';
      this.saveMessage = 'Saved locally, pending sync';

      if (this.onItemSaved) { this.onItemSaved(); }
    } catch (err) {
      this.saveStatus = 'error';
      this.saveMessage = 'Save failed: ' + (err as Error).message;
    } finally {
      this.isSaving = false;
    }
  }
}

// ==================================================================
// Pure helpers for creator comparison (exported for testing)
// ==================================================================

export function creatorsToJson(creators: ZoteroCreator[]): string {
  let arr: Record<string, string>[] = [];
  for (let i = 0; i < creators.length; i++) {
    let entry: Record<string, string> = {
      ct: creators[i].creatorType,
      fn: creators[i].firstName,
      ln: creators[i].lastName,
      fm: `${creators[i].fieldMode}`,
    };
    if ((creators[i].name ?? '').length > 0) {
      entry['nm'] = creators[i].name!;
    }
    arr.push(entry);
  }
  return JSON.stringify(arr);
}

export function creatorsJsonEqual(jsonA: string, creatorsB: ZoteroCreator[]): boolean {
  return jsonA === creatorsToJson(creatorsB);
}

export function tagsToJson(tags: ZoteroTag[]): string {
  let arr: Record<string, string>[] = [];
  for (let i = 0; i < tags.length; i++) {
    arr.push({ tg: tags[i].tag, tp: `${tags[i].type}` });
  }
  return JSON.stringify(arr);
}

export function tagsJsonEqual(jsonA: string, tagsB: ZoteroTag[]): boolean {
  return jsonA === tagsToJson(tagsB);
}
