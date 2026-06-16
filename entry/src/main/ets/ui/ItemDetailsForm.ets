/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: elements/itemDetails.js — main item detail form
 *
 * Draft-based edit with explicit Save/Reset.
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
  @Link item: ItemModel;
  @State itemType: string = 'journalArticle';
  @State draftFields: Map<string, FieldDraft> = new Map();
  @State creators: ZoteroCreator[] = [];
  @State tags: ZoteroTag[] = [];
  @State readOnly: boolean = false;
  @State isSaving: boolean = false;
  @State saveMessage: string = '';
  @State isDirty: boolean = false;
  onItemSaved?: () => void;

  aboutToAppear(): void {
    this._resetDraft();
  }

  /** Rebuild draft from current item. */
  private _resetDraft(): void {
    this.itemType = this.item.itemData.get('itemType') ?? this.item.itemTypeName ?? 'journalArticle';
    this.creators = [...this.item.creators];
    this.tags = [...this.item.tags];
    let fresh = new Map<string, FieldDraft>();
    this.item.itemData.forEach((value: string, key: string) => {
      if (key === 'itemType' || key === 'creator' || key === 'note') { return; }
      fresh.set(key, { oldValue: value, newValue: value, dirty: false });
    });
    // Ensure common fields always exist in draft
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
    this.saveMessage = '';
  }

  build() {
    Column() {
      // ---- Save / Reset bar ----
      Row() {
        if (this.saveMessage.length > 0) {
          Text(this.saveMessage)
            .fontSize(11).fontColor(ZHColor.SUCCESS).layoutWeight(1)
        } else if (this.isDirty) {
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
              if (old !== this.itemType) { this.isDirty = true; }
            },
          })

          // ---- Information section ----
          this._sectionHeader('INFORMATION')

          // Title
          FieldEditor({
            fieldName: 'title',
            fieldValue: this._draftVal('title'),
            onChange: (v: string) => { this._setField('title', v); },
          })
          // Abstract
          FieldEditor({
            fieldName: 'abstractNote',
            fieldValue: this._draftVal('abstractNote'),
            multiline: true,
            onChange: (v: string) => { this._setField('abstractNote', v); },
          })

          // ---- Creators ----
          CreatorEditor({ creators: $creators, readOnly: this.readOnly })

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
              this.isDirty = true;
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

  private _updateDirtyFlag(): void {
    let dirty = false;
    this.draftFields.forEach((fd: FieldDraft, _k: string) => {
      if (fd.dirty) { dirty = true; }
    });
    if (!dirty && this.itemType !== (this.item.itemData.get('itemType') ?? this.item.itemTypeName ?? 'journalArticle')) {
      dirty = true;
    }
    this.isDirty = dirty;
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

  /** Batch-save: type + changed fields + tags → one flush. */
  private async _doSave(): Promise<void> {
    let itemKey = this.item.key ?? '';
    if (itemKey.length === 0) { return; }
    this.isSaving = true;
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
      // 3. Tags
      await repo.replaceItemTags(itemKey, this.tags);
      await repo.close();

      // Update ItemModel in place
      for (let i = 0; i < changedKeys.length; i++) {
        let fd = this.draftFields.get(changedKeys[i])!;
        this.item.itemData.set(changedKeys[i], fd.newValue);
        fd.oldValue = fd.newValue;
        fd.dirty = false;
      }
      this.item.itemData.set('itemType', this.itemType);
      this.item.itemTypeName = this.itemType;
      this.item.tags = this.tags;
      this.isDirty = false;
      this.saveMessage = 'Saved locally, pending sync';

      if (this.onItemSaved) { this.onItemSaved(); }
    } catch (err) {
      this.saveMessage = 'Save failed: ' + (err as Error).message;
    } finally {
      this.isSaving = false;
    }
  }
}
