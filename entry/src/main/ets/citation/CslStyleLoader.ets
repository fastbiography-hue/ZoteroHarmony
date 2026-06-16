/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: xpcom/style.js — CSL style management
 *
 * ***** END LICENSE BLOCK *****
 */

import { resourceManager } from '@kit.LocalizationKit';

/** Minimal style metadata parsed from CSL XML. */
export interface CslStyleMeta {
  styleID: string;
  title: string;
  /** 'note' or 'in-text' */
  class: string;
  hasBibliography: boolean;
  xml: string;
}

/** Bundled default styles (APA, MLA, Chicago, Vancouver, Nature). */
const BUNDLED_STYLE_IDS: string[] = [
  'apa', 'modern-language-association', 'chicago-note-bibliography',
  'vancouver', 'nature',
];

/**
 * Load CSL style XML from bundled assets.
 *
 * In Zotero Desktop, CSL styles live in the `styles/` submodule (~2600 files).
 * For HarmonyOS, we bundle a small set of common styles as rawfile resources.
 *
 * Ref: xpcom/style.js  get() / getTitle() / _hasBibliography()
 */
export class CslStyleLoader {
  private cache: Map<string, CslStyleMeta> = new Map();

  /**
   * Load a style by ID (e.g. 'apa', 'vancouver').
   * First checks cache, then reads from rawfile, then falls back to stub.
   */
  async load(styleID: string): Promise<CslStyleMeta> {
    // Check cache
    let cached = this.cache.get(styleID);
    if (cached) { return cached; }

    // Try bundled rawfile
    try {
      let resMgr = getContext().resourceManager;
      let raw = await resMgr.getRawFileContent(`csl-styles/${styleID}.csl`);
      let decoder = new util.TextDecoder('utf-8');
      let xml = decoder.decodeWithStream(raw);
      let meta = this._parseMeta(styleID, xml);
      this.cache.set(styleID, meta);
      return meta;
    } catch (_e) {
      // Fallback: generate a minimal stub style
      return this._stubStyle(styleID);
    }
  }

  /** Load all bundled styles. */
  async loadBundled(): Promise<CslStyleMeta[]> {
    let results: CslStyleMeta[] = [];
    for (let i = 0; i < BUNDLED_STYLE_IDS.length; i++) {
      results.push(await this.load(BUNDLED_STYLE_IDS[i]));
    }
    return results;
  }

  /** Parse minimal metadata from CSL XML. */
  private _parseMeta(id: string, xml: string): CslStyleMeta {
    let title = id; // default: use ID as title
    let titleMatch = xml.match(/<title[^>]*>([^<]+)<\/title>/);
    if (titleMatch) { title = titleMatch[1]; }

    let styleClass = 'in-text';
    let classMatch = xml.match(/class="([^"]+)"/);
    if (classMatch) { styleClass = classMatch[1]; }

    let hasBib = xml.includes('bibliography');

    return { styleID: id, title, class: styleClass, hasBibliography: hasBib, xml };
  }

  /** Generate a minimal stub style for when the real CSL file is not bundled. */
  private _stubStyle(id: string): CslStyleMeta {
    let xml = `<?xml version="1.0" encoding="utf-8"?>
<style xmlns="http://purl.org/net/xbiblio/csl" class="in-text" version="1.0">
  <info><title>${id}</title><id>http://www.zotero.org/styles/${id}</id></info>
  <citation><layout><text variable="title"/></layout></citation>
  <bibliography><layout><text variable="title"/></layout></bibliography>
</style>`;
    return this._parseMeta(id, xml);
  }

  /** Check if a style has been loaded. */
  isLoaded(styleID: string): boolean {
    return this.cache.has(styleID);
  }

  /** Clear style cache. */
  clearCache(): void { this.cache.clear(); }
}

/** Global singleton for style loading. */
export const cslStyleLoader = new CslStyleLoader();
