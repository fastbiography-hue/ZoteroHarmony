/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ported from Zotero Desktop (AGPL-3.0)
 * Original: chrome/content/zotero/xpcom/data/itemFields.js
 *
 * ***** END LICENSE BLOCK *****
 */

import { ITEM_TYPE_FIELDS } from './ItemTypeFieldsData.ets';
import { ItemType, CSLField } from './ItemTypes.ets';

/**
 * Field ID map — uses a class instead of computed Record<CSLField, number>
 * because ArkTS does not support computed property names in object literals.
 * Ref: itemFields.js  baseFieldMappings
 */
class FieldIDMap {
  private data: Map<string, number> = new Map();
  private reverse: Map<number, string> = new Map();

  constructor() {
    let pairs: [CSLField, number][] = [
      [CSLField.TITLE, 1], [CSLField.ABSTRACT, 2], [CSLField.DATE, 3],
      [CSLField.DOI, 4], [CSLField.ISBN, 5], [CSLField.ISSN, 6],
      [CSLField.URL, 7], [CSLField.ACCESS_DATE, 8], [CSLField.ARCHIVE, 9],
      [CSLField.ARCHIVE_LOCATION, 10], [CSLField.LIBRARY_CATALOG, 11],
      [CSLField.CALL_NUMBER, 12], [CSLField.RIGHTS, 13], [CSLField.EXTRA, 14],
      [CSLField.PAGES, 15], [CSLField.VOLUME, 16], [CSLField.ISSUE, 17],
      [CSLField.SERIES, 18], [CSLField.SERIES_NUMBER, 19], [CSLField.SERIES_TITLE, 20],
      [CSLField.JOURNAL_ABBREVIATION, 21], [CSLField.LANGUAGE, 22],
      [CSLField.SHORT_TITLE, 23], [CSLField.PUBLICATION_TITLE, 24],
      [CSLField.PUBLISHER, 25], [CSLField.PLACE, 26], [CSLField.EDITION, 27],
      [CSLField.NUMBER_OF_VOLUMES, 28], [CSLField.NUMBER, 29], [CSLField.SECTION, 30],
      [CSLField.COURT, 31], [CSLField.REPORTER, 32], [CSLField.REPORTER_VOLUME, 33],
      [CSLField.CITATION_KEY, 34], [CSLField.CREATOR, 35],
      [CSLField.ITEM_TYPE, 36], [CSLField.NOTE, 37],
    ];
    for (let i = 0; i < pairs.length; i++) {
      let f = pairs[i][0] as string;
      let id = pairs[i][1];
      this.data.set(f, id);
      this.reverse.set(id, f);
    }
  }

  getFieldID(field: CSLField): number {
    return this.data.get(field as string) ?? 0;
  }

  getFieldIDByName(name: string): number {
    return this.data.get(name) ?? 0;
  }

  getFieldName(id: number): string {
    return this.reverse.get(id) ?? '';
  }
}

const fieldIDMap = new FieldIDMap();

/**
 * Metadata helper — API-level field validation.
 */
export class ItemFieldsMeta {
  static getFieldsForType(itemType: ItemType): CSLField[] {
    return ITEM_TYPE_FIELDS[itemType] ?? [];
  }

  static isValidForType(field: CSLField, itemType: ItemType): boolean {
    let fields = ITEM_TYPE_FIELDS[itemType];
    if (!fields) { return false; }
    return fields.includes(field);
  }

  static getFieldID(fieldName: string): number {
    return fieldIDMap.getFieldIDByName(fieldName);
  }

  static getFieldName(fieldID: number): string {
    return fieldIDMap.getFieldName(fieldID);
  }
}
