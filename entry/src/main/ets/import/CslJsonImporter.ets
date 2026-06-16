/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: data/item.js:5373  fromJSON() — parse CSL JSON → ItemModel
 *
 * ***** END LICENSE BLOCK *****
 */

import { ItemModel } from '../model/ItemModel.ets';
import { ZoteroCreator } from '../model/ItemTypes.ets';

/** CSL → Zotero creator type mapping (reverse of ItemToCslConverter). */
const CSL_TO_CREATOR_TYPE: Record<string, string> = {
  'author':            'author',
  'editor':            'editor',
  'translator':        'translator',
  'container-author':  'bookAuthor',
  'collection-editor': 'seriesEditor',
};

/**
 * Parse CSL JSON into ItemModel array.
 *
 * Supports both single object and array input.
 * Ref: item.js fromJSON() — maps CSL fields to Zotero itemData.
 */
export class CslJsonImporter {
  /**
   * Parse CSL JSON text. Returns ItemModel[].
   */
  static parse(text: string): ItemModel[] {
    let results: ItemModel[] = [];
    let parsed = JSON.parse(text) as Record<string, Object> | Record<string, Object>[];
    let items = Array.isArray(parsed) ? parsed : [parsed];

    for (let i = 0; i < items.length; i++) {
      let item = CslJsonImporter._parseItem(items[i]);
      if (item) { results.push(item); }
    }
    return results;
  }

  private static _parseItem(json: Record<string, Object>): ItemModel | null {
    let item = new ItemModel();

    // Title
    let title = (json['title'] ?? '') as string;
    item.itemData.set('title', title);

    // Type
    let type = (json['type'] ?? 'article') as string;
    item.itemData.set('type', type);

    // Date
    let issued = json['issued'] as Record<string, Object> | undefined;
    if (issued) {
      let parts = (issued['date-parts'] ?? []) as number[][];
      if (parts.length > 0 && parts[0].length > 0) {
        let y = `${parts[0][0]}`;
        if (parts[0].length > 1) {
          y += `-${String(parts[0][1]).padStart(2, '0')}`;
        }
        if (parts[0].length > 2) {
          y += `-${String(parts[0][2]).padStart(2, '0')}`;
        }
        item.itemData.set('date', y);
      }
    }

    // Creators
    let authorArr = (json['author'] ?? []) as Record<string, Object>[];
    let editorArr = (json['editor'] ?? []) as Record<string, Object>[];
    for (let i = 0; i < authorArr.length; i++) {
      let c = authorArr[i];
      item.creators.push({
        creatorType: 'author',
        firstName: (c['given'] ?? '') as string,
        lastName: (c['family'] ?? '') as string,
        fieldMode: 0,
      });
    }
    for (let i = 0; i < editorArr.length; i++) {
      let c = editorArr[i];
      item.creators.push({
        creatorType: 'editor',
        firstName: (c['given'] ?? '') as string,
        lastName: (c['family'] ?? '') as string,
        fieldMode: 0,
      });
    }

    // Direct field mappings
    let fieldMap: Record<string, string> = {
      'DOI': 'DOI', 'ISBN': 'ISBN', 'ISSN': 'ISSN', 'URL': 'URL',
      'volume': 'volume', 'issue': 'issue', 'page': 'pages',
      'publisher': 'publisher', 'publisher-place': 'place',
      'container-title': 'publicationTitle', 'abstract': 'abstractNote',
      'note': 'extra', 'language': 'language', 'edition': 'edition',
    };
    let fmKeys = Object.keys(fieldMap);
    for (let i = 0; i < fmKeys.length; i++) {
      let cslKey = fmKeys[i];
      let val = json[cslKey];
      if (val !== undefined && val !== null) {
        item.itemData.set(fieldMap[cslKey], `${val}`);
      }
    }

    return item;
  }
}
