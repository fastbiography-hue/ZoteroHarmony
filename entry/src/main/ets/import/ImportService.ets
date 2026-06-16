/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: xpcom/import/ — unified import service with format detection
 *
 * ***** END LICENSE BLOCK *****
 */

import { ItemModel } from '../model/ItemModel.ets';
import { BibTeXImporter } from './BibTeXImporter.ets';
import { RisImporter } from './RisImporter.ets';
import { CslJsonImporter } from './CslJsonImporter.ets';
import { IdentifierLookup } from './IdentifierLookup.ets';

export type ImportFormat = 'bibtex' | 'ris' | 'csljson' | 'auto';

/** Result of an import operation. */
export interface ImportResult {
  items: ItemModel[];
  format: string;
  count: number;
  warnings: string[];
}

/**
 * Unified import entry point — auto-detect format and parse.
 *
 * Supported formats: BibTeX (.bib), RIS (.ris), CSL JSON (.json)
 */
export class ImportService {
  /**
   * Import text in any supported format. Auto-detection by default.
   */
  static importText(text: string, format: ImportFormat = 'auto'): ImportResult {
    let warnings: string[] = [];

    // Auto-detect
    if (format === 'auto') {
      format = ImportService._detectFormat(text);
    }

    let items: ItemModel[];
    switch (format) {
      case 'bibtex':
        items = BibTeXImporter.parse(text);
        break;
      case 'ris':
        items = RisImporter.parse(text);
        break;
      case 'csljson':
        items = CslJsonImporter.parse(text);
        break;
      default:
        return { items: [], format: 'unknown', count: 0, warnings: ['Unknown format'] };
    }

    if (items.length === 0) {
      warnings.push('No items found in input');
    }

    return { items, format, count: items.length, warnings };
  }

  /**
   * Import from a single identifier string (DOI, ISBN, arXiv, PMID).
   * Returns null if not a recognizable identifier.
   */
  static fromIdentifier(text: string): string | null {
    let type = IdentifierLookup.classify(text);
    if (type === 'unknown') { return null; }
    return IdentifierLookup.buildLookupPath(type, text);
  }

  /**
   * Detect format from text content.
   */
  private static _detectFormat(text: string): ImportFormat {
    let trimmed = text.trim();
    if (trimmed.startsWith('@')) { return 'bibtex'; }
    if (trimmed.startsWith('TY  -')) { return 'ris'; }
    if (trimmed.startsWith('[') || trimmed.startsWith('{')) {
      try {
        JSON.parse(trimmed);
        return 'csljson';
      } catch (_e) { /* fall through */ }
    }
    // Default: try BibTeX (most permissive)
    return 'bibtex';
  }

  /** Get list of supported file extensions. */
  static supportedExtensions(): string[] {
    return ['.bib', '.ris', '.json', '.csl.json', '.txt'];
  }
}
