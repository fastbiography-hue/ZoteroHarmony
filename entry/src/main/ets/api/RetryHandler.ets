/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ported from Zotero Desktop (AGPL-3.0)
 *
 * Ref: xpcom/http.js:1577-1588  429 / 5xx retry with backoff
 * Ref: xpcom/sync/syncAPIClient.js:43-44  rateDelayIntervals
 * Ref: xpcom/sync/syncEngine.js:31  conflictDelayIntervals
 *
 * ***** END LICENSE BLOCK *****
 */

import { ZoteroHttpError } from './ZoteroHttpError.ets';

/** Default backoff intervals in milliseconds: [2.5s, 5s, 10s, 20s, 40s, 60s, 120s, 240s, 300s] */
const DEFAULT_BACKOFF = [2500, 5000, 10000, 20000, 40000, 60000, 120000, 240000, 300000];

/** One hour max total wait. Ref: http.js:8: _errorDelayMax */
const MAX_BACKOFF_MS = 60 * 60 * 1000;

/**
 * Exponential-backoff retry handler for HTTP operations.
 *
 * Behaviour:
 *   - Retries on 429 (with Retry-After delay) and 5xx
 *   - 4xx (non-429) are NOT retried — rethrown immediately
 *   - If `fn` succeeds, returns its result
 *   - After maxRetries attempts, throws the last error
 */
export class RetryHandler {
  /**
   * Execute `fn` with automatic retry on retryable errors.
   *
   * @param fn        — async function returning T
   * @param maxRetries — maximum attempts (default 3)
   * @param backoffMs — custom backoff intervals (default: DEFAULT_BACKOFF)
   * @returns result of fn on success
   * @throws ZoteroHttpError on final failure (or any non-retryable error)
   */
  static async retryWithBackoff<T>(
    fn: () => Promise<T>,
    maxRetries: number = 3,
    backoffMs: number[] = DEFAULT_BACKOFF
  ): Promise<T> {
    let totalWait = 0;
    let lastError: Error | null = null;

    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await fn();
      } catch (err) {
        if (err instanceof ZoteroHttpError && err.isRetryable()) {
          lastError = err;
          if (attempt >= maxRetries) {
            throw err; // exhausted retries
          }
          // Compute delay: prefer Retry-After header over backoff table
          let delayMs = err.retryAfter > 0
            ? err.retryAfter * 1000
            : (backoffMs[attempt] ?? backoffMs[backoffMs.length - 1]);
          // Cap total wait
          if (totalWait + delayMs > MAX_BACKOFF_MS) {
            throw err;
          }
          totalWait += delayMs;
          await RetryHandler._sleep(delayMs);
          continue;
        }
        // Non-retryable (e.g., 403, 404, 409, 412, 413) — throw immediately
        throw err;
      }
    }
    throw lastError ?? new Error('RetryHandler: unexpected state');
  }

  /** Promise-based sleep. */
  private static _sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: (value: void) => void) => {
      setTimeout(resolve, ms);
    });
  }
}
