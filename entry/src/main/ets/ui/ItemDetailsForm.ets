/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: elements/itemDetails.js — main item detail form
 *
 * ***** END LICENSE BLOCK *****
 */

import { ItemFieldsMeta } from '../model/ItemFieldsMeta.ets';
import { ItemType, CSLField } from '../model/ItemTypes.ets';
import { ItemModel } from '../model/ItemModel.ets';
import { ZoteroCreator, ZoteroTag } from '../model/ItemTypes.ets';
import { ItemTypeDropdown } from './ItemTypeDropdown.ets';
import { FieldEditor } from './FieldEditor.ets';
import { CreatorEditor } from './CreatorEditor.ets';
import { TagChipEditor } from './TagChipEditor.ets';
import { LibraryRepository } from '../database/LibraryRepository.ets';

/**
 * Main item detail form — type selector + field editors + creator/tag editors.
 * Ref: elements/itemDetails.js
 */
@Component
export struct ItemDetailsForm {
  @Link item: ItemModel;
  @State itemType: ItemType = ItemType.JOURNAL_ARTICLE;
  @State fieldValues: Map<string, string> = new Map();
  @State creators: ZoteroCreator[] = [];
  @State tags: ZoteroTag[] = [];
  @State readOnly: boolean = false;

  aboutToAppear(): void {
    this.fieldValues = new Map(this.item.itemData);
    this.creators = [...this.item.creators];
    this.tags = [...this.item.tags];
  }

  build() {
    Scroll() {
      Column() {
        // Type selector
        ItemTypeDropdown({
          selectedType: this.itemType,
          disabled: this.readOnly,
          onChange: (newType: ItemType) => { this.itemType = newType; },
        })

        // ---- Information section ----
        this._sectionHeader('INFORMATION')

        FieldEditor({
          fieldName: 'title', fieldValue: this.fieldValues.get('title') ?? '',
          onChange: (v: string) => { this._updateField('title', v); },
        })
        FieldEditor({
          fieldName: 'abstractNote', fieldValue: this.fieldValues.get('abstractNote') ?? '', multiline: true,
          onChange: (v: string) => { this._updateField('abstractNote', v); },
        })

        // ---- Creators ----
        CreatorEditor({ creators: $creators, readOnly: this.readOnly })

        // ---- Publication section ----
        this._sectionHeader('PUBLICATION')

        FieldEditor({
          fieldName: 'date', fieldValue: this.fieldValues.get('date') ?? '',
          onChange: (v: string) => { this._updateField('date', v); },
        })
        FieldEditor({
          fieldName: 'DOI', fieldValue: this.fieldValues.get('DOI') ?? '',
          onChange: (v: string) => { this._updateField('DOI', v); },
        })
        FieldEditor({
          fieldName: 'url', fieldValue: this.fieldValues.get('url') ?? '',
          onChange: (v: string) => { this._updateField('url', v); },
        })
        FieldEditor({
          fieldName: 'publicationTitle', fieldValue: this.fieldValues.get('publicationTitle') ?? '',
          onChange: (v: string) => { this._updateField('publicationTitle', v); },
        })
        FieldEditor({
          fieldName: 'volume', fieldValue: this.fieldValues.get('volume') ?? '',
          onChange: (v: string) => { this._updateField('volume', v); },
        })
        FieldEditor({
          fieldName: 'issue', fieldValue: this.fieldValues.get('issue') ?? '',
          onChange: (v: string) => { this._updateField('issue', v); },
        })
        FieldEditor({
          fieldName: 'pages', fieldValue: this.fieldValues.get('pages') ?? '',
          onChange: (v: string) => { this._updateField('pages', v); },
        })

        // ---- Extra section ----
        this._sectionHeader('EXTRA')

        FieldEditor({
          fieldName: 'extra', fieldValue: this.fieldValues.get('extra') ?? '', multiline: true,
          onChange: (v: string) => { this._updateField('extra', v); },
        })

        // ---- Tags ----
        TagChipEditor({
          tags: $tags,
          readOnly: this.readOnly,
          onTagsChange: (tags: ZoteroTag[]) => {
            this._saveTags(tags);
          },
        })

        Blank().height(40)
      }
      .width('100%')
    }
  }

  @Builder
  _sectionHeader(title: string) {
    Text(title)
      .fontSize(12).fontColor('#999')
      .fontWeight(FontWeight.Bold).width('100%')
      .padding({ left: 12, top: 12, bottom: 4 })
      .border({ width: { top: 1 }, color: '#EEEEEE' })
  }

  private _updateField(fieldName: string, value: string): void {
    this.fieldValues.set(fieldName, value);
    this.item.itemData.set(fieldName, value);
    let itemKey = this.item.key ?? '';
    if (itemKey.length === 0) {
      return;
    }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.updateItemField(itemKey, fieldName, value);
    }).then(() => {
      repo.close();
    }).catch((_err: Error) => {
      repo.close();
    });
  }

  private _saveTags(tags: ZoteroTag[]): void {
    this.item.tags = tags;
    let itemKey = this.item.key ?? '';
    if (itemKey.length === 0) {
      return;
    }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.replaceItemTags(itemKey, tags);
    }).then(() => {
      repo.close();
    }).catch((_err: Error) => {
      repo.close();
    });
  }
}
