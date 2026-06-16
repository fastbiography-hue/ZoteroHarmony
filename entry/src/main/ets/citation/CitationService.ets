/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: xpcom/cite.js — makeFormattedBibliography + citeproc-rs bridge
 *
 * ***** END LICENSE BLOCK *****
 */

import { ItemModel } from '../model/ItemModel.ets';
import { ExportService, ExportFormat } from '../import/ExportService.ets';
import { CitationFormatter } from './CitationFormatter.ets';

export type CitationFormat = 'html' | 'text' | 'rtf';

/** CSL locale names Zotero supports. Ref: cite.js locale cache. */
const SUPPORTED_LOCALES: string[] = [
  'en-US', 'zh-CN', 'de-DE', 'fr-FR', 'ja-JP', 'ko-KR',
  'es-ES', 'pt-BR', 'it-IT', 'ru-RU', 'nl-NL', 'ar',
];

/**
 * Citation formatting service — minimal stub that formats
 * bibliography entries without a full CSL engine.
 *
 * When citeproc-rs WASM becomes available on HarmonyOS,
 * replace _formatEntry with engine.makeBibliography() calls.
 *
 * Ref: xpcom/cite.js:193-405  makeFormattedBibliographyOrCitationList
 * Ref: xpcom/citeprocRsBridge.js  Engine class
 */
export class CitationService {
  static supportedLocales(): string[] { return [...SUPPORTED_LOCALES]; }

  /**
   * Generate a formatted bibliography for the given items.
   * Currently uses a simplified HTML template; full CSL rendering
   * requires citeproc-rs wasm module.
   */
  static generateBibliography(
    items: ItemModel[],
    styleName: string = 'apa',
    format: CitationFormat = 'html',
    locale: string = 'en-US'
  ): string {
    if (format === 'html') {
      let entries: string[] = [];
      for (let i = 0; i < items.length; i++) {
        entries.push(CitationService._formatEntryHTML(items[i], i + 1, styleName, locale));
      }
      return `<div class="csl-bib-body">\n${entries.join('\n')}\n</div>`;
    }
    if (format === 'text') {
      let lines: string[] = [];
      for (let i = 0; i < items.length; i++) {
        lines.push(CitationService._formatEntryText(items[i], i + 1, styleName));
      }
      return lines.join('\n\n');
    }
    // RTF: return raw text with minimal RTF wrapping
    let lines: string[] = ['{\\rtf1\\ansi'];
    for (let i = 0; i < items.length; i++) {
      lines.push(CitationService._formatEntryText(items[i], i + 1, styleName) + '\\\n');
    }
    lines.push('}');
    return lines.join('');
  }

  /**
   * Generate a single inline citation.
   * Ref: cite.js:204  previewCitationCluster
   */
  static generateCitation(
    item: ItemModel,
    format: CitationFormat = 'text',
    locale: string = 'en-US',
    styleName: string = 'apa'
  ): string {
    let citation = CitationFormatter.formatCitation(item, styleName, 1);

    if (format === 'html') {
      return `<span class="citation">${citation}</span>`;
    }
    return citation;
  }

  /** Export items as CSL JSON, then format via ExportService. */
  static exportFormatted(items: ItemModel[], format: ExportFormat): string {
    return ExportService.exportItems(items, format);
  }

  // ==================================================================
  // Private — simplified CSL rendering stubs
  // ==================================================================

  private static _formatEntryHTML(item: ItemModel, num: number, styleName: string, _locale: string): string {
    let kind = CitationFormatter.styleKind(styleName);
    let lead = kind === 'numeric'
      ? CitationFormatter.formatNumericLine(item, num)
      : CitationFormatter.formatAuthorYearLine(item);
    let doi = item.itemData.get('DOI');
    let doiStr = doi ? ` <a href="https://doi.org/${doi}">${doi}</a>` : '';
    return `  <div class="csl-entry">${lead}${doiStr}</div>`;
  }

  private static _formatEntryText(item: ItemModel, num: number, styleName: string): string {
    if (CitationFormatter.styleKind(styleName) === 'numeric') {
      return CitationFormatter.formatNumericLine(item, num);
    }
    return CitationFormatter.formatAuthorYearLine(item);
  }
}
