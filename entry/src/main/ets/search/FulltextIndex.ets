/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: xpcom/fulltext.js — fulltext indexing and word search
 *
 * ***** END LICENSE BLOCK *****
 */

/** One word entry in the fulltext index. */
interface WordEntry {
  word: string;
  itemIDs: Set<number>;
}

// Common stop words excluded from indexing.
const STOP_WORDS: Set<string> = new Set([
  'the', 'a', 'an', 'and', 'or', 'but', 'in', 'on', 'at',
  'to', 'for', 'of', 'with', 'by', 'from', 'is', 'are', 'was',
  'were', 'be', 'been', 'being', 'have', 'has', 'had', 'do',
  'does', 'did', 'will', 'would', 'could', 'should', 'may',
  'might', 'can', 'shall', 'this', 'that', 'these', 'those',
  'it', 'its', 'they', 'them', 'their',
]);

/**
 * In-memory fulltext word index.
 *
 * For each item, tokenize its searchable text (title, abstract, creators)
 * into lowercase words, excluding stop words.
 *
 * Ref: xpcom/fulltext.js  semanticSplitter + findTextInItems
 */
export class FulltextIndex {
  private index: Map<string, Set<number>> = new Map();

  /**
   * Index one item. Call whenever an item is created or updated.
   */
  indexItem(itemID: number, textFields: string[]): void {
    let words = FulltextIndex._tokenize(textFields.join(' '));
    for (let i = 0; i < words.length; i++) {
      let w = words[i];
      let ids = this.index.get(w) ?? new Set();
      ids.add(itemID);
      this.index.set(w, ids);
    }
  }

  /**
   * Remove an item from the index (on delete).
   */
  removeItem(itemID: number): void {
    this.index.forEach((ids: Set<number>, _word: string) => {
      ids.delete(itemID);
    });
  }

  /**
   * Search for items containing ALL of the given words.
   * Returns matching itemIDs.
   */
  search(words: string[]): number[] {
    if (words.length === 0) { return []; }
    let tokens = FulltextIndex._tokenize(words.join(' '));
    if (tokens.length === 0) { return []; }

    // Intersection of all word sets
    let result: Set<number> | null = null;
    for (let i = 0; i < tokens.length; i++) {
      let idsSet = this.index.get(tokens[i]);
      if (idsSet === undefined || idsSet.size === 0) {
        return []; // word missing → no match
      }
      let ids = idsSet as Set<number>;
      if (result === null) {
        result = new Set(ids);
      } else {
        let intersection = new Set<number>();
        result.forEach((id: number) => {
          if (ids.has(id)) { intersection.add(id); }
        });
        result = intersection;
      }
      if (result.size === 0) { return []; }
    }
    return result ? Array.from(result) : [];
  }

  /**
   * Get total number of indexed terms.
   */
  get termCount(): number { return this.index.size; }

  /**
   * Clear the entire index.
   */
  clear(): void { this.index.clear(); }

  // ==================================================================
  // Tokenizer
  // ==================================================================

  /**
   * Split text into normalized tokens, excluding stop words.
   * Ref: fulltext.js  semanticSplitter
   */
  private static _tokenize(text: string): string[] {
    let words = text.toLowerCase()
      .replace(/[^a-z0-9À-ɏ\s]/g, ' ')
      .split(/\s+/)
      .filter((w: string) => w.length > 1 && !STOP_WORDS.has(w));
    // Deduplicate
    return Array.from(new Set(words));
  }
}

/**
 * Utility: split a search phrase into semantic tokens.
 * Handles quoted strings and boolean-style grouping.
 */
export function semanticSplitter(phrase: string): string[] {
  let results: string[] = [];
  // Extract quoted substrings
  let quotedRe = /"([^"]+)"/g;
  let match: RegExpExecArray | null;
  let remaining = phrase;
  while ((match = quotedRe.exec(phrase)) !== null) {
    results.push(match[1]);
    remaining = remaining.replace(match[0], ' ');
  }
  // Split remaining by whitespace
  let parts = remaining.split(/\s+/);
  for (let i = 0; i < parts.length; i++) {
    if (parts[i].length > 0) { results.push(parts[i]); }
  }
  return results;
}
