/*
 * Unit tests for RetryHandler.
 *
 * Covers:
 *   - Success on first attempt (no retry)
 *   - Retry on 429 and succeed on retry #1
 *   - Max-retries exhausted → throw
 *   - Non-retryable 4xx → throw immediately
 *   - Edge: maxRetries=0
 */

import { describe, it, expect } from '@ohos/hypium';
import { RetryHandler } from '../../main/ets/api/RetryHandler.ets';
import { ZoteroHttpError } from '../../main/ets/api/ZoteroHttpError.ets';

export default function () {
  describe('RetryHandler', () => {
    it('should return result on first success', async () => {
      let count = 0;
      let result = await RetryHandler.retryWithBackoff<string>(async (): Promise<string> => {
        count++;
        return `ok-${count}`;
      });
      expect(result).assertEqual('ok-1');
      expect(count).assertEqual(1);
    });

    it('should retry on 429 and succeed on second attempt', async () => {
      let attempt = 0;
      let result = await RetryHandler.retryWithBackoff<string>(async (): Promise<string> => {
        attempt++;
        if (attempt === 1) {
          throw ZoteroHttpError.rateLimited(0); // 0s → ~2.5s backoff
        }
        return `saved-at-${attempt}`;
      }, 3, [10]); // 10ms backoff for fast test
      expect(result).assertEqual('saved-at-2');
      expect(attempt).assertEqual(2);
    });

    it('should throw after maxRetries exhausted', async () => {
      let attempt = 0;
      let thrown = false;
      try {
        await RetryHandler.retryWithBackoff<string>(
          async (): Promise<string> => {
            attempt++;
            throw ZoteroHttpError.rateLimited(0);
          },
          2,              // maxRetries=2 → 3 attempts total
          [10, 10, 10]
        );
      } catch (err) {
        thrown = true;
        expect(err instanceof ZoteroHttpError).assertTrue();
        expect((err as ZoteroHttpError).statusCode).assertEqual(429);
      }
      expect(thrown).assertTrue();
      expect(attempt).assertEqual(3); // attempt 0,1,2 = 3 tries
    });

    it('should NOT retry on 403 (non-retryable 4xx)', async () => {
      let attempt = 0;
      let thrown = false;
      try {
        await RetryHandler.retryWithBackoff<string>(async (): Promise<string> => {
          attempt++;
          throw ZoteroHttpError.unauthorized();
        }, 3);
      } catch (err) {
        thrown = true;
        expect(err instanceof ZoteroHttpError).assertTrue();
        expect((err as ZoteroHttpError).statusCode).assertEqual(403);
      }
      expect(thrown).assertTrue();
      expect(attempt).assertEqual(1); // no retry
    });

    it('should handle maxRetries=0', async () => {
      let attempt = 0;
      let thrown = false;
      try {
        await RetryHandler.retryWithBackoff<string>(async (): Promise<string> => {
          attempt++;
          throw ZoteroHttpError.rateLimited(0);
        }, 0);
      } catch (_err) {
        thrown = true;
      }
      expect(thrown).assertTrue();
      expect(attempt).assertEqual(1);
    });

    it('should not throw when fn never fails', async () => {
      let result = await RetryHandler.retryWithBackoff<number>(async (): Promise<number> => {
        return 42;
      }, 5);
      expect(result).assertEqual(42);
    });
  });
}
