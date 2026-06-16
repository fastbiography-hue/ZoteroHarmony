/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: xpcom/exportOptions.js  export in BibTeX / RIS / CSL JSON formats
 *
 * ***** END LICENSE BLOCK *****
 */

import { ItemModel } from '../model/ItemModel.ets';
import { ZoteroCreator } from '../model/ItemTypes.ets';

export type ExportFormat = 'bibtex' | 'ris' | 'csljson';

/**
 * Export one or more items to a formatted string.
 *
 * Replaces: chrome/content/zotero/exportOptions.js
 */
export class ExportService {
  /** Export items array to the requested format. */
  static exportItems(items: ItemModel[], format: ExportFormat): string {
    switch (format) {
      case 'bibtex':  return ExportService._toBibTeX(items);
      case 'ris':     return ExportService._toRIS(items);
      case 'csljson': return ExportService._toCSLJSON(items);
    }
  }

  /** BibTeX export — minimal implementation. */
  private static _toBibTeX(items: ItemModel[]): string {
    let lines: string[] = [];
    for (let i = 0; i < items.length; i++) {
      let item = items[i];
      let citeKey = item.itemData.get('citationKey') ?? ExportService._bibtexKey(item);
      let type = item.itemTypeID === null ? 'misc' : 'article';
      lines.push(`@${type}{${citeKey},`);
      lines.push(`  title = {${item.itemData.get('title') ?? ''}},`);
      let creators = item.creators;
      if (creators.length > 0) {
        let c = creators[0];
        lines.push(`  author = {${c.lastName}, ${c.firstName}},`);
      } else {
        let creator = item.itemData.get('creator');
        if (creator) { lines.push(`  author = {${creator}},`); }
      }
      let year = (item.itemData.get('date') ?? '').match(/(\d{4})/);
      if (year) { lines.push(`  year = {${year[1]}},`); }
      let doi = item.itemData.get('DOI');
      if (doi) { lines.push(`  doi = {${doi}},`); }
      lines.push('}\n');
    }
    return lines.join('\n');
  }

  /** RIS export. */
  private static _toRIS(items: ItemModel[]): string {
    let lines: string[] = [];
    for (let i = 0; i < items.length; i++) {
      let item = items[i];
      lines.push('TY  - JOUR');
      let title = item.itemData.get('title');
      if (title) { lines.push(`TI  - ${title}`); }
      for (let j = 0; j < item.creators.length; j++) {
        let c = item.creators[j];
        lines.push(`AU  - ${c.lastName}, ${c.firstName}`);
      }
      if (item.creators.length === 0) {
        let creator = item.itemData.get('creator');
        if (creator) { lines.push(`AU  - ${creator}`); }
      }
      let year = (item.itemData.get('date') ?? '').match(/(\d{4})/);
      if (year) { lines.push(`PY  - ${year[1]}`); }
      let doi = item.itemData.get('DOI');
      if (doi) { lines.push(`DO  - ${doi}`); }
      lines.push('ER  - \n');
    }
    return lines.join('\n');
  }

  /** CSL JSON export — delegates to ItemModel.toJSON(). */
  private static _toCSLJSON(items: ItemModel[]): string {
    let arr: object[] = [];
    for (let i = 0; i < items.length; i++) {
      arr.push(items[i].toJSON('full'));
    }
    return JSON.stringify(arr, null, 2);
  }

  /** Generate a BibTeX citation key: AuthorYear. */
  private static _bibtexKey(item: ItemModel): string {
    let author = '';
    let creators = item.creators;
    if (creators.length > 0) {
      author = creators[0].lastName.replace(/[^a-zA-Z]/g, '');
    } else {
      author = (item.itemData.get('creator') ?? '').replace(/[^a-zA-Z]/g, '');
    }
    let year = (item.itemData.get('date') ?? '').match(/(\d{4})/);
    return `${author || 'unknown'}${year ? year[1] : '0000'}`;
  }
}
