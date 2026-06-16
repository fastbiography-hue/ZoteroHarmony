/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: xpcom/utilities/utilities_item.js  itemToCSLJSON()
 *      — converts Zotero.Item to CSL-JSON format expected by citeproc
 *
 * ***** END LICENSE BLOCK *****
 */

import { ItemModel } from '../model/ItemModel.ets';
import { ZoteroCreator } from '../model/ItemTypes.ets';
import { ExtraFieldParser } from './ExtraFieldParser.ets';

/** CSL creator role mapping. */
const CREATOR_TYPE_TO_CSL: Record<string, string> = {
  'author':      'author',
  'editor':      'editor',
  'translator':  'translator',
  'contributor': 'contributor',
  'bookAuthor':  'container-author',
  'seriesEditor':'collection-editor',
};

/** Zotero itemType → CSL type mapping. */
const ITEM_TYPE_TO_CSL: Record<string, string> = {
  'journalArticle':     'article-journal',
  'book':              'book',
  'bookSection':       'chapter',
  'conferencePaper':   'paper-conference',
  'thesis':            'thesis',
  'report':            'report',
  'webpage':           'webpage',
  'note':              'article',
  'attachment':        'article',
  'magazineArticle':   'article-magazine',
  'newspaperArticle':  'article-newspaper',
  'blogPost':          'post-weblog',
  'preprint':          'article',
  'presentation':      'speech',
  'interview':         'interview',
  'film':              'motion_picture',
  'podcast':           'broadcast',
  'map':               'map',
  'patent':            'patent',
};

/**
 * Convert Zotero ItemModel to CSL-JSON for citeproc rendering.
 * Ref: utilities_item.js  itemToCSLJSON()
 */
export class ItemToCslConverter {
  /**
   * Convert one item. Returns a Record compatible with CSL JSON spec.
   */
  static convert(item: ItemModel): Record<string, Object> {
    let csl: Record<string, Object> = {};

    // id (required by citeproc)
    csl['id'] = item.id ?? 0;

    // type
    let typeID = item.itemTypeID;
    let typeName = typeID !== null ? `${typeID}` : 'article';
    csl['type'] = ITEM_TYPE_TO_CSL[typeName] ?? 'article';

    // title
    let title = item.itemData.get('title') ?? '';
    csl['title'] = title;

    // creators → CSL author/editor arrays
    let creators = item.creators;
    let authorList: Record<string, string>[] = [];
    let editorList: Record<string, string>[] = [];
    for (let i = 0; i < creators.length; i++) {
      let c = creators[i];
      let role = CREATOR_TYPE_TO_CSL[c.creatorType] ?? 'author';
      let entry: Record<string, string> = {
        family: c.lastName, given: c.firstName,
      };
      if (role === 'author') { authorList.push(entry); }
      else if (role === 'editor') { editorList.push(entry); }
    }
    if (authorList.length > 0) { csl['author'] = authorList; }
    if (editorList.length > 0) { csl['editor'] = editorList; }

    // issued date
    let date = item.itemData.get('date') ?? '';
    let dateParts = ItemToCslConverter._parseDate(date);
    if (dateParts.length > 0) {
      csl['issued'] = { 'date-parts': [dateParts] };
    }

    // Identifiers
    let doi = item.itemData.get('DOI');
    if (doi) { csl['DOI'] = doi; }
    let isbn = item.itemData.get('ISBN');
    if (isbn) { csl['ISBN'] = isbn; }
    let issn = item.itemData.get('ISSN');
    if (issn) { csl['ISSN'] = issn; }
    let url = item.itemData.get('url');
    if (url) { csl['URL'] = url; }

    // Publication
    let pubTitle = item.itemData.get('publicationTitle');
    if (pubTitle) { csl['container-title'] = pubTitle; }
    let volume = item.itemData.get('volume');
    if (volume) { csl['volume'] = volume; }
    let issue = item.itemData.get('issue');
    if (issue) { csl['issue'] = issue; }
    let pages = item.itemData.get('pages');
    if (pages) { csl['page'] = pages; }
    let publisher = item.itemData.get('publisher');
    if (publisher) { csl['publisher'] = publisher; }
    let place = item.itemData.get('place');
    if (place) { csl['publisher-place'] = place; }

    // Extra → parse CSL variables
    let extra = item.itemData.get('extra') ?? '';
    if (extra) {
      let parsed = ExtraFieldParser.parse(extra);
      parsed.fields.forEach((v: string, k: string) => { csl[k] = v; });
    }

    return csl;
  }

  /** Convert array of items. */
  static convertAll(items: ItemModel[]): Record<string, Object>[] {
    let result: Record<string, Object>[] = [];
    for (let i = 0; i < items.length; i++) {
      result.push(ItemToCslConverter.convert(items[i]));
    }
    return result;
  }

  /** Parse SQL date → [year, month?, day?] */
  private static _parseDate(date: string): number[] {
    // Try YYYY, YYYY-MM, YYYY-MM-DD
    let m = date.match(/^(\d{4})(?:-(\d{2})(?:-(\d{2}))?)?/);
    if (!m) { return []; }
    let parts: number[] = [parseInt(m[1])];
    if (m[2]) {
      let month = parseInt(m[2]);
      if (month >= 1 && month <= 12) { parts.push(month); }
    }
    if (parts.length > 1 && m[3]) {
      let day = parseInt(m[3]);
      if (day >= 1 && day <= 31) { parts.push(day); }
    }
    return parts;
  }
}
