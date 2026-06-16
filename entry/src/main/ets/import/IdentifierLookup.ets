/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: xpcom/lookup.js + xpcom/isbn.js — DOI/ISBN/PMID/arXiv lookup
 *
 * ***** END LICENSE BLOCK *****
 */

/**
 * Validate and normalize common scholarly identifiers.
 */
export class IdentifierLookup {
  /**
   * Check if a string is a valid DOI.
   * DOI pattern: 10.XXXX/XXXX
   */
  static isDOI(text: string): boolean {
    return /^10\.\d{4,}\/[^\s]+$/.test(text.trim());
  }

  /**
   * Check if a string is a valid ISBN-10 or ISBN-13.
   * Ref: xpcom/isbn.js  validateISBN()
   */
  static isISBN(text: string): boolean {
    let cleaned = text.replace(/[-\s]/g, '');
    if (cleaned.length === 10) {
      return IdentifierLookup._isValidISBN10(cleaned);
    }
    if (cleaned.length === 13) {
      return IdentifierLookup._isValidISBN13(cleaned);
    }
    return false;
  }

  /** Clean an ISBN string, removing hyphens/spaces. */
  static cleanISBN(text: string): string {
    return text.replace(/[-\s]/g, '').toUpperCase();
  }

  /**
   * Check if a string looks like an arXiv ID.
   * Patterns: arXiv:1901.01234, 1901.01234v1
   */
  static isArXiv(text: string): boolean {
    return /^(?:arXiv:)?\d{4}\.\d{4,5}(?:v\d+)?$/i.test(text.trim());
  }

  /**
   * Check if a string is a PMID (PubMed ID — 1-8 digit number).
   */
  static isPMID(text: string): boolean {
    return /^\d{1,8}$/.test(text.trim());
  }

  /**
   * Classify an input string by identifier type.
   * Returns 'doi' | 'isbn' | 'arxiv' | 'pmid' | 'unknown'.
   */
  static classify(text: string): string {
    let t = text.trim();
    if (IdentifierLookup.isDOI(t)) { return 'doi'; }
    if (IdentifierLookup.isISBN(t)) { return 'isbn'; }
    if (IdentifierLookup.isArXiv(t)) { return 'arxiv'; }
    if (IdentifierLookup.isPMID(t)) { return 'pmid'; }
    return 'unknown';
  }

  /** Build a Zotero API lookup URL for the given identifier. */
  static buildLookupPath(type: string, value: string): string | null {
    switch (type) {
      case 'doi':   return `/items/search?doi=${encodeURIComponent(value)}`;
      case 'isbn':  return `/items/search?isbn=${encodeURIComponent(value)}`;
      case 'pmid':  return `/items/search?pmid=${encodeURIComponent(value)}`;
      case 'arxiv': return `/items/search?arxiv=${encodeURIComponent(value)}`;
      default:      return null;
    }
  }

  // ==================================================================
  // Private validation
  // ==================================================================

  /** Validate ISBN-10 checksum. */
  private static _isValidISBN10(isbn: string): boolean {
    let sum = 0;
    for (let i = 0; i < 9; i++) {
      let d = parseInt(isbn[i]);
      if (isNaN(d)) { return false; }
      sum += d * (10 - i);
    }
    let last = isbn[9];
    sum += last === 'X' ? 10 : parseInt(last);
    return sum % 11 === 0;
  }

  /** Validate ISBN-13 checksum. */
  private static _isValidISBN13(isbn: string): boolean {
    let sum = 0;
    for (let i = 0; i < 12; i++) {
      let d = parseInt(isbn[i]);
      if (isNaN(d)) { return false; }
      sum += d * (i % 2 === 0 ? 1 : 3);
    }
    let check = (10 - (sum % 10)) % 10;
    return check === parseInt(isbn[12]);
  }
}
