/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: xpcom/citeprocRsBridge.js  Engine class
 *      xpcom/cite.js  makeFormattedBibliographyOrCitationList
 *
 * When citeproc-rs WASM is available, replace _formatBibliography()
 * with actual Driver.insertReference() + Driver.makeBibliography() calls.
 *
 * ***** END LICENSE BLOCK *****
 */

import { ItemModel } from '../model/ItemModel.ets';
import { CslStyleLoader, CslStyleMeta, cslStyleLoader } from './CslStyleLoader.ets';
import { CslLocaleLoader, cslLocaleLoader } from './CslLocaleLoader.ets';
import { CitationFormatter } from './CitationFormatter.ets';

export type OutputFormat = 'html' | 'text' | 'rtf';

/** Result of a bibliography generation. */
export interface BibliographyResult {
  /** Formatted bibliography entries (HTML/Text/RTF). */
  entries: string[];
  /** Style metadata. */
  styleTitle: string;
  /** Locale used. */
  locale: string;
}

/**
 * Main citation engine — orchestrates style loading, locale resolution,
 * CSL-JSON conversion, and formatted output generation.
 *
 * Design: all citeproc-rs WASM calls are isolated behind private methods
 * so that swapping in the real WASM engine requires changing only this class.
 *
 * Ref: citeprocRsBridge.js:76-282  Engine class
 */
export class CitationEngine {
  private styleLoader: CslStyleLoader;
  private localeLoader: CslLocaleLoader;
  private style: CslStyleMeta | null = null;

  constructor(styleLoader?: CslStyleLoader, localeLoader?: CslLocaleLoader) {
    this.styleLoader = styleLoader ?? cslStyleLoader;
    this.localeLoader = localeLoader ?? cslLocaleLoader;
  }

  /** Load a CSL style by ID. */
  async setStyle(styleID: string): Promise<CslStyleMeta> {
    this.style = await this.styleLoader.load(styleID);
    return this.style;
  }

  get currentStyle(): CslStyleMeta | null { return this.style; }

  // ==================================================================
  // Bibliography generation
  // Ref: citeprocRsBridge.js:247-281  makeBibliography()
  // ==================================================================

  async generateBibliography(
    items: ItemModel[],
    format: OutputFormat = 'html',
    localeTag: string = 'en-US'
  ): Promise<BibliographyResult> {
    if (!this.style) { throw new Error('No CSL style loaded — call setStyle() first'); }

    // Load locale
    let locale = await this.localeLoader.resolve(localeTag);

    // TODO: When citeproc-rs WASM is available:
    //   let driver = new CiteprocRs.Driver({ style: this.style.xml, format, fetcher });
    //   for (let cslItem of cslItems) { driver.insertReference(cslItem); }
    //   let entries = driver.makeBibliography();
    //
    // Current stub: format with simplified template
    let entries = this._formatEntries(items, this.style, format);

    return {
      entries,
      styleTitle: this.style.title,
      locale: locale.lang,
    };
  }

  // ==================================================================
  // Inline citation
  // Ref: citeprocRsBridge.js:171-188  previewCitationCluster()
  // ==================================================================

  generateCitation(
    items: ItemModel[],
    format: OutputFormat = 'text',
    localeTag: string = 'en-US'
  ): string {
    if (items.length === 0) { return ''; }
    let citation = CitationFormatter.formatCitation(items[0], this.style ? this.style.styleID : 'apa', 1);

    if (format === 'html') {
      return `<span class="citation">${citation}</span>`;
    }
    return citation;
  }

  // ==================================================================
  // Private: simplified formatting (stub until citeproc-rs WASM)
  // ==================================================================

  private _formatEntries(
    items: ItemModel[],
    style: CslStyleMeta,
    format: OutputFormat
  ): string[] {
    let results: string[] = [];
    let kind = style.class === 'note' ? 'note' : CitationFormatter.styleKind(style.styleID);

    for (let i = 0; i < items.length; i++) {
      let item = items[i];
      let authorYear = CitationFormatter.formatAuthorYearLine(item);
      let numeric = CitationFormatter.formatNumericLine(item, i + 1);
      let entry = kind === 'numeric' ? numeric : authorYear;

      if (format === 'html') {
        results.push(`<div class="csl-entry">${entry}</div>`);
      } else if (format === 'text') {
        results.push(entry);
      } else {
        results.push(entry);
      }
    }
    return results;
  }
}

/** Global singleton. */
export const citationEngine = new CitationEngine();
