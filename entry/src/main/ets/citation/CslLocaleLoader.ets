/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: xpcom/cite.js:702  Zotero.Cite.Locale  — retrieveLocale()
 *
 * ***** END LICENSE BLOCK *****
 */

import { resourceManager } from '@kit.LocalizationKit';

/** CSL locale data. */
export interface CslLocale {
  lang: string;
  xml: string;
}

/**
 * Load CSL locale XML files from bundled assets.
 *
 * Ref: xpcom/cite.js:702-719  Zotero.Cite.Locale.get()
 *      chrome/content/zotero/locale/csl/locales-*.xml
 */
export class CslLocaleLoader {
  private cache: Map<string, CslLocale> = new Map();

  /** Locales bundled with the app. */
  static readonly BUNDLED_LOCALES: string[] = [
    'en-US', 'zh-CN', 'de-DE', 'fr-FR', 'ja-JP', 'es-ES',
  ];

  /**
   * Load a locale by code (e.g. 'en-US', 'zh-CN').
   * Returns locale data or null if not found.
   */
  async load(lang: string): Promise<CslLocale | null> {
    // Check cache
    let cached = this.cache.get(lang);
    if (cached) { return cached; }

    try {
      let resMgr = getContext().resourceManager;
      let raw = await resMgr.getRawFileContent(`csl-locales/locales-${lang}.xml`);
      let decoder = new util.TextDecoder('utf-8');
      let xml = decoder.decodeWithStream(raw);
      let locale: CslLocale = { lang, xml };
      this.cache.set(lang, locale);
      return locale;
    } catch (_e) {
      // Try fallback to en-US
      if (lang !== 'en-US') {
        return this.load('en-US');
      }
      return null;
    }
  }

  /**
   * Resolve the best CSL locale for a given BCP-47 tag.
   * Falls back to 'en-US' if no match found.
   */
  async resolve(localeTag: string): Promise<CslLocale> {
    // Try exact match first
    let locale = await this.load(localeTag);
    if (locale) { return locale; }

    // Try primary language only (e.g. 'zh-CN' → 'zh')
    let primary = localeTag.split('-')[0];
    let candidates = CslLocaleLoader.BUNDLED_LOCALES.filter((l: string) => l.startsWith(primary));
    for (let i = 0; i < candidates.length; i++) {
      locale = await this.load(candidates[i]);
      if (locale) { return locale; }
    }

    // Final fallback: en-US
    let en = await this.load('en-US');
    return en!;
  }

  /** Check if a locale is loaded. */
  isLoaded(lang: string): boolean { return this.cache.has(lang); }

  /** Clear the locale cache. */
  clearCache(): void { this.cache.clear(); }
}

export const cslLocaleLoader = new CslLocaleLoader();
