/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: translators/RIS.js — RIS format parser
 *
 * ***** END LICENSE BLOCK *****
 */

import { ItemModel } from '../model/ItemModel.ets';
import { ZoteroCreator } from '../model/ItemTypes.ets';

/** RIS type tag → Zotero itemType mapping. */
const RIS_TYPE_MAP: Record<string, string> = {
  'JOUR':  'journalArticle',  'JFULL': 'journalArticle',
  'BOOK':  'book',            'CHAP':  'bookSection',
  'CONF':  'conferencePaper', 'CPAPER':'conferencePaper',
  'THES':  'thesis',          'RPRT':  'report',
  'ELEC':  'webpage',         'WEB':   'webpage',
  'MGZN':  'magazineArticle', 'NEWS':  'newspaperArticle',
  'PAT':   'patent',          'GEN':   'document',
  'UNPB':  'manuscript',      'PCOMM': 'document',
};

/** RIS tag → CSL field mapping. */
const RIS_TAG_MAP: Record<string, string> = {
  'T1': 'title',   'TI': 'title',    'CT': 'title',
  'T2': 'publicationTitle',  'BT': 'publicationTitle',
  'JF': 'publicationTitle',  'JO': 'publicationTitle',
  'AB': 'abstractNote',  'N2': 'abstractNote',
  'PY': 'date',   'Y1': 'date',     'DA': 'date',
  'DO': 'DOI',    'SN': 'ISSN',     'UR': 'url',
  'VL': 'volume', 'IS': 'issue',    'SP': 'pages',
  'PB': 'publisher',  'CY': 'place',
  'KW': 'tags',   'ER': '',         'N1': 'extra',
};

/**
 * Parse RIS format text into ItemModel array.
 */
export class RisImporter {
  static parse(text: string): ItemModel[] {
    let results: ItemModel[] = [];
    let records = text.split(/\nTY\s+-/);
    for (let i = 1; i < records.length; i++) {
      let item = RisImporter._parseRecord('TY  -' + records[i]);
      if (item) { results.push(item); }
    }
    return results;
  }

  private static _parseRecord(record: string): ItemModel | null {
    let lines = record.split(/\r?\n/);
    let item = new ItemModel();
    let authors: ZoteroCreator[] = [];
    let tags: string[] = [];

    for (let i = 0; i < lines.length; i++) {
      let line = lines[i];
      let m = line.match(/^([A-Z0-9]{2})\s+-\s+(.*)/);
      if (!m) { continue; }
      let tag = m[1]; let value = m[2].trim();
      if (!value) { continue; }

      // Type detection
      if (tag === 'TY') {
        let zType = RIS_TYPE_MAP[value] ?? 'document';
        // store type for later assignment
      }
      // Authors
      if (tag === 'AU' || tag === 'A1' || tag === 'A2') {
        let c = RisImporter._parseCreator(value);
        if (c) { authors.push(c); }
        continue;
      }
      if (tag === 'ED') {
        let c = RisImporter._parseCreator(value);
        if (c) { c.creatorType = 'editor'; authors.push(c); }
        continue;
      }
      // Tags
      if (tag === 'KW') {
        tags.push(value);
        continue;
      }
      // End of record
      if (tag === 'ER') { break; }
      // Map to CSL field
      let field = RIS_TAG_MAP[tag];
      if (field && field !== 'tags') {
        item.itemData.set(field, value);
      }
    }
    return item;
  }

  private static _parseCreator(raw: string): ZoteroCreator | null {
    let trimmed = raw.trim();
    if (!trimmed) { return null; }
    let comma = trimmed.indexOf(',');
    if (comma >= 0) {
      return {
        creatorType: 'author',
        lastName: trimmed.substring(0, comma).trim(),
        firstName: trimmed.substring(comma + 1).trim(),
        fieldMode: 0,
      };
    }
    let parts = trimmed.split(/\s+/);
    return {
      creatorType: 'author',
      lastName: parts.pop() ?? '',
      firstName: parts.join(' '),
      fieldMode: 0,
    };
  }
}
