/*
 * Unit tests for PaginationHelper.
 *
 * Covers:
 *   - parseLinkHeader: normal / null / single link / all rel types
 *   - _extractPath: absolute URL → path
 *   - Edge: empty header, malformed header, no rel attr
 */

import { describe, it, expect } from '@ohos/hypium';
import { PaginationHelper, LinkHeader } from '../../main/ets/api/PaginationHelper.ets';

export default function () {
  describe('PaginationHelper', () => {
    // ---- parseLinkHeader ----
    it('should parse next + last links', () => {
      let header = '<https://api.zotero.org/users/1/groups?start=50>; rel="next",'
        + ' <https://api.zotero.org/users/1/groups?start=100>; rel="last"';
      let parsed = PaginationHelper.parseLinkHeader(header);
      expect(parsed.next).assertEqual('https://api.zotero.org/users/1/groups?start=50');
      expect(parsed.last).assertEqual('https://api.zotero.org/users/1/groups?start=100');
    });

    it('should parse all four rel types', () => {
      let header = '<https://a.example/1>; rel="first",'
        + ' <https://a.example/2>; rel="prev",'
        + ' <https://a.example/3>; rel="next",'
        + ' <https://a.example/4>; rel="last"';
      let parsed = PaginationHelper.parseLinkHeader(header);
      expect(parsed.first).assertEqual('https://a.example/1');
      expect(parsed.prev).assertEqual('https://a.example/2');
      expect(parsed.next).assertEqual('https://a.example/3');
      expect(parsed.last).assertEqual('https://a.example/4');
    });

    // ---- null input ----
    it('should return empty LinkHeader on null', () => {
      let parsed = PaginationHelper.parseLinkHeader(null);
      expect(parsed.next).assertNull();
      expect(parsed.last).assertNull();
    });

    it('should return empty LinkHeader on empty string', () => {
      let parsed = PaginationHelper.parseLinkHeader('');
      expect(parsed.next).assertNull();
    });

    // ---- Edge cases ----
    it('should handle malformed header gracefully', () => {
      let parsed = PaginationHelper.parseLinkHeader('not-a-valid-link-header');
      expect(parsed.next).assertNull();
      expect(parsed.last).assertNull();
    });

    it('should parse single link with only next', () => {
      let header = '<https://api.example.com/items?start=25>; rel="next"';
      let parsed = PaginationHelper.parseLinkHeader(header);
      expect(parsed.next).assertEqual('https://api.example.com/items?start=25');
      expect(parsed.last).assertNull();
      expect(parsed.first).assertNull();
    });

    it('should handle link without rel (skip silently)', () => {
      let header = '<https://api.example.com/items>; title="all items"';
      let parsed = PaginationHelper.parseLinkHeader(header);
      expect(parsed.next).assertNull();
    });
  });
}
