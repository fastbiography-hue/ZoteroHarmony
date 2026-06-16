/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: translators/ BibTeX.js — BibTeX parser
 * Ported to ArkTS with simplified grammar subset
 *
 * ***** END LICENSE BLOCK *****
 */

import { ItemModel } from '../model/ItemModel.ets';
import { ZoteroCreator } from '../model/ItemTypes.ets';
import { ItemType, CSLField } from '../model/ItemTypes.ets';

/** BibTeX entry type → Zotero ItemType mapping. */
const BIBTEX_TYPE_MAP: Record<string, string> = {
  'article':       'journalArticle',
  'book':          'book',
  'inbook':        'bookSection',
  'incollection':  'bookSection',
  'inproceedings': 'conferencePaper',
  'conference':    'conferencePaper',
  'phdthesis':     'thesis',
  'mastersthesis': 'thesis',
  'techreport':    'report',
  'misc':          'document',
  'unpublished':   'manuscript',
  'manual':        'document',
  'proceedings':   'book',
};

/**
 * Parse BibTeX .bib text into ItemModel array.
 *
 * Grammar subset supported:
 *   @type{citationKey,
 *     field = {value},
 *     field = "value",
 *     author = {Last, First and Last2, First2},
 *   }
 */
export class BibTeXImporter {
  /**
   * Parse BibTeX text. Returns array of ItemModel (unsaved).
   */
  static parse(text: string): ItemModel[] {
    let results: ItemModel[] = [];
    let entries = BibTeXImporter._splitEntries(text);

    for (let i = 0; i < entries.length; i++) {
      let item = BibTeXImporter._parseEntry(entries[i]);
      if (item) { results.push(item); }
    }
    return results;
  }

  /** Split text into @entry{...} blocks. */
  private static _splitEntries(text: string): string[] {
    let results: string[] = [];
    let depth = 0;
    let start = -1;
    for (let i = 0; i < text.length; i++) {
      if (text[i] === '{') { depth++; }
      if (text[i] === '}') { depth--; }
      if (text[i] === '@' && depth === 0) { start = i; }
      if (depth === 0 && start >= 0 && text[i] === '}') {
        results.push(text.substring(start, i + 1));
        start = -1;
      }
    }
    return results;
  }

  /** Parse one @type{key, fields} entry. */
  private static _parseEntry(entry: string): ItemModel | null {
    let headMatch = entry.match(/@(\w+)\s*\{\s*([^,]+),/);
    if (!headMatch) { return null; }
    let bibType = headMatch[1].toLowerCase();
    let citeKey = headMatch[2].trim();

    let item = new ItemModel();
    // map BibTeX type to Zotero type — store as field
    item.itemData.set('citationKey', citeKey);

    // Parse fields — key = {value} or key = "value"
    let fieldRe = /(\w+)\s*=\s*[{"]([^}"]*)[}"]/g;
    let match: RegExpExecArray | null;
    let creators: ZoteroCreator[] = [];

    while ((match = fieldRe.exec(entry)) !== null) {
      let key = match[1].toLowerCase();
      let value = BibTeXImporter._unescape(match[2]);

      switch (key) {
        case 'title':  item.itemData.set('title', value); break;
        case 'journal': item.itemData.set('publicationTitle', value); break;
        case 'booktitle': item.itemData.set('publicationTitle', value); break;
        case 'volume': item.itemData.set('volume', value); break;
        case 'number': item.itemData.set('issue', value); break;
        case 'pages':  item.itemData.set('pages', value); break;
        case 'year':   item.itemData.set('date', value); break;
        case 'date':   item.itemData.set('date', value); break;
        case 'doi':    item.itemData.set('DOI', value); break;
        case 'isbn':   item.itemData.set('ISBN', value); break;
        case 'issn':   item.itemData.set('ISSN', value); break;
        case 'url':    item.itemData.set('url', value); break;
        case 'publisher': item.itemData.set('publisher', value); break;
        case 'abstract':  item.itemData.set('abstractNote', value); break;
        case 'author':
        case 'editor':
          let parsed = BibTeXImporter._parseAuthors(value, key);
          for (let pa = 0; pa < parsed.length; pa++) { creators.push(parsed[pa]); }
          break;
      }
    }
    item.itemData.set('creators', creators.length > 0 ? 'true' : '');
    return item;
  }

  /** Parse "Last, First and Last2, First2" → ZoteroCreator[]. */
  private static _parseAuthors(raw: string, role: string): ZoteroCreator[] {
    let result: ZoteroCreator[] = [];
    let parts = raw.split(/\s+and\s+/);
    for (let i = 0; i < parts.length; i++) {
      let p = parts[i].trim();
      if (!p) { continue; }
      let comma = p.indexOf(',');
      let lastName: string;
      let firstName: string;
      if (comma >= 0) {
        lastName = p.substring(0, comma).trim();
        firstName = p.substring(comma + 1).trim();
      } else {
        let words = p.split(/\s+/);
        lastName = words.pop() ?? '';
        firstName = words.join(' ');
      }
      result.push({
        creatorType: role === 'editor' ? 'editor' : 'author',
        firstName, lastName, fieldMode: 0,
      });
    }
    return result;
  }

  /** Unescape LaTeX special chars. */
  private static _unescape(s: string): string {
    return s
      .replace(/\\&/g, '&')
      .replace(/\\%/g, '%')
      .replace(/\\#/g, '#')
      .replace(/\\_/g, '_')
      .replace(/\{\\(.)\}/g, '$1')
      .replace(/[{}]/g, '')
      .trim();
  }
}
