/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ported from Zotero Desktop (AGPL-3.0)
 *
 * Ref: syncAPIClient.js:923-979  getPaginatedResults / _parseLinkHeader
 *
 * ***** END LICENSE BLOCK *****
 */

import { HttpClient, HttpResponse } from './HttpClient.ets';

/** Result of parsing a Link header. */
export interface LinkHeader {
  next: string | null;
  last: string | null;
  first: string | null;
  prev: string | null;
}

/**
 * Pagination utility — replaces Generator-based pagination with async/await.
 *
 * Ref: syncAPIClient.js:923-949  getPaginatedResults
 */
export class PaginationHelper {
  /**
   * Parse an HTTP Link header into rel→URL map.
   *
   * Format: <https://api.example.com/items?start=50>; rel="next",
   *         <https://api.example.com/items?start=100>; rel="last"
   *
   * Ref: syncAPIClient.js:960-979  _parseLinkHeader
   * Original regex-based parser MIT-licensed.
   */
  static parseLinkHeader(header: string | null): LinkHeader {
    let result: LinkHeader = { next: null, last: null, first: null, prev: null };
    if (!header) { return result; }

    // Split on commas outside angle brackets
    let parts = header.split(/,(?=\s*<)/);
    for (let i = 0; i < parts.length; i++) {
      let part = parts[i].trim();
      let urlMatch = part.match(/<([^>]+)>/);
      let relMatch = part.match(/rel="([^"]+)"/);
      if (urlMatch && relMatch) {
        let url = urlMatch[1];
        let rel = relMatch[1];
        switch (rel) {
          case 'next':  result.next = url;  break;
          case 'last':  result.last = url;  break;
          case 'first': result.first = url; break;
          case 'prev':  result.prev = url;  break;
        }
      }
    }
    return result;
  }

  /**
   * Fetch all pages by following `rel="next"` links.
   *
   * @param firstPath — API path (without base URL), e.g. "/users/1/groups"
   * @param httpClient — configured HttpClient instance
   * @param maxPages  — safety limit (default 50)
   * @returns merged array of all items
   *
   * Ref: syncAPIClient.js:923-949  getPaginatedResults
   */
  static async fetchAllPages<T>(
    firstPath: string,
    httpClient: HttpClient,
    maxPages: number = 50
  ): Promise<T[]> {
    let result: T[] = [];
    let currentPath: string | null = firstPath;
    let pagesFetched = 0;

    while (currentPath && pagesFetched < maxPages) {
      let response: HttpResponse<T[] | T> = await httpClient.get<T[] | T>(currentPath);
      pagesFetched++;

      // Accumulate — response data may be an array or single object
      if (!response.data) { currentPath = null; continue; }
      if (Array.isArray(response.data)) {
        let arr = response.data as T[];
        for (let i = 0; i < arr.length; i++) { result.push(arr[i]); }
      } else {
        result.push(response.data as T);
      }

      // Follow Link header to next page
      let linkHeader = (response.headers['link'] ?? null) as string | null;
      let link = PaginationHelper.parseLinkHeader(linkHeader);
      if (link.next) {
        // next URL may be absolute — extract path
        currentPath = PaginationHelper._extractPath(link.next);
      } else {
        currentPath = null;
      }
    }
    return result;
  }

  /** Extract path from an absolute URL (strips base). */
  private static _extractPath(absoluteUrl: string): string {
    try {
      // URL may not be available in all ArkTS contexts; fallback to regex
      let match = absoluteUrl.match(/https?:\/\/[^/]+(\/.*)/);
      return match ? match[1] : absoluteUrl;
    } catch (_e) {
      return absoluteUrl;
    }
  }
}
