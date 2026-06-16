/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: xpcom/utilities_internal.js:1049-1276  extractExtraFields / combineExtraFields
 *
 * ***** END LICENSE BLOCK *****
 */

/**
 * CSL variable names that can appear in the Extra field.
 * Ref: Zotero.Utilities.Internal  _normalizeExtraKey / extractExtraFields
 */
const CSL_EXTRA_KEYS: string[] = [
  'DOI', 'ISBN', 'ISSN', 'PMID', 'PMCID', 'arXiv',
  'JSTOR', 'URL', 'original-date', 'language',
  'publisher', 'publisher-place', 'title-short',
  'container-title', 'container-title-short',
  'volume', 'issue', 'page', 'number-of-volumes',
  'edition', 'event', 'event-place', 'event-date',
  'genre', 'medium', 'note', 'annote',
  'abstract', 'keyword',
];

/** Parsed Extra content: fields map + remaining unparsed text. */
export interface ParsedExtra {
  fields: Map<string, string>;
  remaining: string;
}

/**
 * Parse CSL variables from the Extra field text.
 * Lines matching "Key: Value" are extracted; the rest stays as plain text.
 *
 * Ref: utilities_internal.js:1049-1234
 */
export class ExtraFieldParser {
  /**
   * Extract fields from Extra text. Returns structured fields + remaining raw text.
   */
  static parse(extra: string): ParsedExtra {
    let fields = new Map<string, string>();
    let remaining: string[] = [];
    let lines = extra.split(/\r?\n/);

    for (let i = 0; i < lines.length; i++) {
      let line = lines[i];
      let match = line.match(/^([A-Za-z][A-Za-z -]+?):\s*(.+)$/);
      if (match) {
        let key = ExtraFieldParser._normalizeKey(match[1]);
        if (CSL_EXTRA_KEYS.includes(key)) {
          fields.set(key, match[2].trim());
          continue;
        }
      }
      remaining.push(line);
    }
    return { fields, remaining: remaining.join('\n').trim() };
  }

  /**
   * Combine parsed fields back into an Extra string.
   * Sorted alphabetically by key.
   */
  static combine(fields: Map<string, string>, existingExtra: string): string {
    let sorted = Array.from(fields.entries()).sort((a: [string, string], b: [string, string]) => {
      if (a[0] < b[0]) { return -1; }
      if (a[0] > b[0]) { return 1; }
      return 0;
    });
    let fieldLines: string[] = [];
    for (let i = 0; i < sorted.length; i++) {
      fieldLines.push(`${sorted[i][0]}: ${sorted[i][1]}`);
    }
    if (existingExtra) { fieldLines.push(existingExtra); }
    return fieldLines.join('\n');
  }

  /**
   * Normalize a key from Extra: lowercase, strip spaces, standardize known variants.
   * Ref: utilities_internal.js:1277-1287
   */
  static _normalizeKey(raw: string): string {
    let normalized = raw.trim().toLowerCase().replace(/\s+/g, '-');
    // Standardize known variants
    let aliases: Record<string, string> = {
      'original-date': 'original-date',
      'originaldate': 'original-date',
      'pub-location': 'publisher-place',
      'publocation': 'publisher-place',
      'call-number': 'call-number',
      'callnumber': 'call-number',
      'short-title': 'title-short',
      'shorttitle': 'title-short',
    };
    return aliases[normalized] ?? normalized;
  }
}
