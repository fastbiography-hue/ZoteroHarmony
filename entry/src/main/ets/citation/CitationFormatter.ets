/*
 * Shared citation/ bibliography formatting helpers.
 *
 * Keeps the simplified Zotero Harmony citation output consistent across
 * quick copy and preview surfaces without requiring a full citeproc engine.
 */

import { ItemModel } from '../model/ItemModel.ets';
import { ZoteroCreator } from '../model/ItemTypes.ets';

export type CitationStyleKind = 'author-year' | 'numeric' | 'note';

export interface BibliographyParts {
  contributors: string;
  year: string;
  title: string;
  container: string;
  publisher: string;
  identifiers: string;
}

export class CitationFormatter {
  static styleKind(styleName: string): CitationStyleKind {
    let normalized = styleName.toLowerCase();
    if (normalized.includes('note') || normalized.includes('chicago')) {
      return 'note';
    }
    if (normalized.includes('numeric') || normalized.includes('ieee') ||
      normalized.includes('vancouver') || normalized.includes('number')) {
      return 'numeric';
    }
    return 'author-year';
  }

  static formatCitation(item: ItemModel, styleName: string, index: number): string {
    let kind = this.styleKind(styleName);
    let contributors = this.formatContributorList(item);
    let year = this.extractYear(item);
    let title = this.cleanText(item.itemData.get('title') ?? item.displayTitle ?? '(untitled)');
    if (kind === 'numeric') {
      return `[${index}]`;
    }
    if (kind === 'note') {
      let lead = contributors.length > 0 ? contributors : title;
      return `${lead}. ${title}${year.length > 0 ? ` (${year})` : ''}.`;
    }
    let lead = contributors.length > 0 ? contributors : title;
    return `(${lead}${year.length > 0 ? `, ${year}` : ''})`;
  }

  static formatBibliographyParts(item: ItemModel): BibliographyParts {
    let title = this.cleanText(item.itemData.get('title') ?? item.displayTitle ?? '(untitled)');
    let year = this.extractYear(item);
    return {
      contributors: this.formatContributorList(item),
      year: year,
      title: title,
      container: this.formatContainer(item),
      publisher: this.formatPublisherLine(item),
      identifiers: this.formatIdentifiers(item),
    };
  }

  static formatAuthorYearLine(item: ItemModel): string {
    let parts = this.formatBibliographyParts(item);
    let year = parts.year.length > 0 ? ` (${parts.year})` : ' (n.d.)';
    let lead = parts.contributors.length > 0 ? parts.contributors : '';
    let head = lead.length > 0 ? `${lead}${year}` : `${parts.title}${year}`;
    let body = lead.length > 0 ? parts.title : '';
    let line = `${head}.`;
    if (body.length > 0) {
      line += ` ${body}`;
    }
    if (parts.container.length > 0) {
      line += parts.container;
    }
    if (parts.publisher.length > 0) {
      line += parts.publisher;
    }
    if (parts.identifiers.length > 0) {
      line += parts.identifiers;
    }
    return line;
  }

  static formatNumericLine(item: ItemModel, index: number): string {
    let parts = this.formatBibliographyParts(item);
    let year = parts.year.length > 0 ? parts.year : 'n.d.';
    let lead = parts.contributors.length > 0 ? parts.contributors : parts.title;
    let line = `${index}. ${lead} (${year}).`;
    if (parts.contributors.length > 0) {
      line += ` ${parts.title}`;
    }
    if (parts.container.length > 0) {
      line += parts.container;
    }
    if (parts.publisher.length > 0) {
      line += parts.publisher;
    }
    if (parts.identifiers.length > 0) {
      line += parts.identifiers;
    }
    return line;
  }

  static formatContributorList(item: ItemModel): string {
    let creators = item.creators;
    if (creators.length > 0) {
      return this.formatCreators(creators);
    }
    return this.cleanText(item.itemData.get('creator') ?? '');
  }

  static extractYear(item: ItemModel): string {
    let year = (item.itemData.get('date') ?? '').match(/(\d{4})/);
    return year ? year[1] : '';
  }

  static formatContainer(item: ItemModel): string {
    let publicationTitle = this.cleanText(item.itemData.get('publicationTitle') ?? '');
    let journal = this.cleanText(item.itemData.get('journalAbbreviation') ?? '');
    let volume = this.cleanText(item.itemData.get('volume') ?? '');
    let issue = this.cleanText(item.itemData.get('issue') ?? '');
    let pages = this.cleanText(item.itemData.get('pages') ?? '');

    let parts: string[] = [];
    if (publicationTitle.length > 0) {
      parts.push(publicationTitle);
    } else if (journal.length > 0) {
      parts.push(journal);
    }
    if (volume.length > 0) {
      parts.push(volume + (issue.length > 0 ? `(${issue})` : ''));
    } else if (issue.length > 0) {
      parts.push(`(${issue})`);
    }
    if (pages.length > 0) {
      parts.push(`pp. ${pages}`);
    }
    return parts.length > 0 ? ` ${parts.join(', ')}.` : '';
  }

  static formatPublisherLine(item: ItemModel): string {
    let publisher = this.cleanText(item.itemData.get('publisher') ?? '');
    let place = this.cleanText(item.itemData.get('place') ?? '');
    let edition = this.cleanText(item.itemData.get('edition') ?? '');
    let parts: string[] = [];
    if (place.length > 0 && publisher.length > 0) {
      parts.push(`${place}: ${publisher}`);
    } else if (publisher.length > 0) {
      parts.push(publisher);
    }
    if (edition.length > 0) {
      parts.push(`${edition} ed.`);
    }
    return parts.length > 0 ? ` ${parts.join(', ')}.` : '';
  }

  static formatIdentifiers(item: ItemModel): string {
    let doi = this.cleanText(item.itemData.get('DOI') ?? '');
    let url = this.cleanText(item.itemData.get('url') ?? '');
    let parts: string[] = [];
    if (doi.length > 0) {
      parts.push(`https://doi.org/${doi}`);
    }
    if (url.length > 0) {
      parts.push(url);
    }
    return parts.length > 0 ? ` ${parts.join(' | ')}.` : '';
  }

  private static formatCreators(creators: ZoteroCreator[]): string {
    let names: string[] = [];
    for (let i = 0; i < creators.length; i++) {
      let creator = creators[i];
      let name = this.cleanText(creator.lastName);
      if (creator.fieldMode === 0 && creator.firstName.length > 0) {
        name = `${name}, ${this.cleanText(creator.firstName)}`;
      } else if (creator.fieldMode !== 0 && creator.firstName.length > 0) {
        name = this.cleanText(creator.firstName);
      }
      if (name.length > 0) {
        names.push(name);
      }
    }
    if (names.length === 0) {
      return '';
    }
    if (names.length === 1) {
      return names[0];
    }
    if (names.length === 2) {
      return `${names[0]} & ${names[1]}`;
    }
    return `${names[0]} et al.`;
  }

  private static cleanText(value: string): string {
    return value.replace(/\s+/g, ' ').trim();
  }
}
