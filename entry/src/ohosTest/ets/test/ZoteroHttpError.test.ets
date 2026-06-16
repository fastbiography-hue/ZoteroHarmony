/*
 * Unit tests for ZoteroHttpError.
 *
 * Covers:
 *   - Normal construction with all factory methods
 *   - retryAfter defaults to 0
 *   - is4xx() / is5xx() / isRetryable() boundary checks
 *   - Custom message passthrough
 */

import { describe, it, expect } from '@ohos/hypium';
import { ZoteroHttpError } from '../../main/ets/api/ZoteroHttpError.ets';

export default function () {
  describe('ZoteroHttpError', () => {
    // ---- Factory correctness ----
    it('badRequest should have statusCode 400', () => {
      let e = ZoteroHttpError.badRequest();
      expect(e.statusCode).assertEqual(400);
      expect(e.retryAfter).assertEqual(0);
    });

    it('unauthorized should have statusCode 403', () => {
      let e = ZoteroHttpError.unauthorized();
      expect(e.statusCode).assertEqual(403);
    });

    it('notFound should have statusCode 404', () => {
      let e = ZoteroHttpError.notFound();
      expect(e.statusCode).assertEqual(404);
    });

    it('conflict should have statusCode 409', () => {
      let e = ZoteroHttpError.conflict();
      expect(e.statusCode).assertEqual(409);
    });

    it('precondition should have statusCode 412', () => {
      let e = ZoteroHttpError.precondition();
      expect(e.statusCode).assertEqual(412);
    });

    it('payloadTooLarge should have statusCode 413', () => {
      let e = ZoteroHttpError.payloadTooLarge();
      expect(e.statusCode).assertEqual(413);
    });

    it('rateLimited should take retryAfter parameter', () => {
      let e = ZoteroHttpError.rateLimited(30);
      expect(e.statusCode).assertEqual(429);
      expect(e.retryAfter).assertEqual(30);
    });

    // ---- Custom message ----
    it('should accept custom message via factory method', () => {
      let e = ZoteroHttpError.badRequest('Custom message');
      expect(e.message).assertEqual('Custom message');
    });

    // ---- null / undefined input ----
    it('badRequest with empty args should not crash', () => {
      let e = ZoteroHttpError.badRequest();
      expect(e instanceof ZoteroHttpError).assertTrue();
      expect(e instanceof Error).assertTrue();
    });

    it('rateLimited with 0 should still be valid', () => {
      let e = ZoteroHttpError.rateLimited(0);
      expect(e.statusCode).assertEqual(429);
      expect(e.retryAfter).assertEqual(0);
    });

    // ---- is4xx / is5xx / isRetryable ----
    it('is4xx should return true for 4xx codes', () => {
      expect(ZoteroHttpError.badRequest().is4xx()).assertTrue();
      expect(ZoteroHttpError.notFound().is4xx()).assertTrue();
      expect(ZoteroHttpError.conflict().is4xx()).assertTrue();
      expect(ZoteroHttpError.rateLimited(1).is4xx()).assertTrue();
    });

    it('is4xx should return false for non-4xx', () => {
      // There are no 5xx factory methods — test with manual construction
      let e = new ZoteroHttpError(500, 'Server Error');
      expect(e.is4xx()).assertFalse();
      expect(e.is5xx()).assertTrue();
    });

    it('isRetryable should return true for 429 and 5xx', () => {
      expect(ZoteroHttpError.rateLimited(10).isRetryable()).assertTrue();
      let e500 = new ZoteroHttpError(503, 'Unavailable');
      expect(e500.isRetryable()).assertTrue();
    });

    it('isRetryable should return false for 4xx (non-429)', () => {
      expect(ZoteroHttpError.badRequest().isRetryable()).assertFalse();
      expect(ZoteroHttpError.notFound().isRetryable()).assertFalse();
      expect(ZoteroHttpError.precondition().isRetryable()).assertFalse();
    });
  });
}
