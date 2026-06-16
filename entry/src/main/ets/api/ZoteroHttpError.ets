/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ported from Zotero Desktop (AGPL-3.0)
 *
 * Ref: xpcom/http.js:46-97  UnexpectedStatusException
 * Ref: xpcom/sync/syncEngine.js  upload/download result codes
 * Ref: xpcom/sync/syncAPIClient.js:62-68  successCodes patterns
 *
 * ***** END LICENSE BLOCK *****
 */

/**
 * HTTP-level error with factory methods for each Zotero API status code.
 */
export class ZoteroHttpError extends Error {
  /** HTTP status code. */
  readonly statusCode: number;

  /** Seconds to wait before retrying (from Retry-After header). */
  readonly retryAfter: number;

  constructor(statusCode: number, message: string, retryAfter: number = 0) {
    super(message);
    this.name = 'ZoteroHttpError';
    this.statusCode = statusCode;
    this.retryAfter = retryAfter;
  }

  // ==================================================================
  // Static factory methods
  // Ref: http.js:46-97  error patterns per status code
  // ==================================================================

  /** 400 — Bad Request. */
  static badRequest(message: string = 'Bad Request'): ZoteroHttpError {
    return new ZoteroHttpError(400, message);
  }

  /** 403 — API key invalid or access denied. Ref: error.js:48-49 */
  static unauthorized(message: string = 'API key not valid or access denied'): ZoteroHttpError {
    return new ZoteroHttpError(403, message);
  }

  /** 404 — Resource not found. */
  static notFound(message: string = 'Resource not found'): ZoteroHttpError {
    return new ZoteroHttpError(404, message);
  }

  /** 409 — Conflict (e.g. since param before delete log start). Ref: syncAPIClient.js:161 */
  static conflict(message: string = 'Conflict — full sync required'): ZoteroHttpError {
    return new ZoteroHttpError(409, message);
  }

  /** 412 — Precondition Failed (library version mismatch). Ref: syncEngine.js:215 */
  static precondition(message: string = 'Library version conflict'): ZoteroHttpError {
    return new ZoteroHttpError(412, message);
  }

  /** 413 — Payload Too Large (field/tag/note too long). Ref: syncRunner.js:1168 */
  static payloadTooLarge(message: string = 'Entity too large'): ZoteroHttpError {
    return new ZoteroHttpError(413, message);
  }

  /** 429 — Too Many Requests. n = seconds from Retry-After header. */
  static rateLimited(retryAfterSeconds: number): ZoteroHttpError {
    return new ZoteroHttpError(
      429,
      `Rate limited — retry after ${retryAfterSeconds}s`,
      retryAfterSeconds
    );
  }

  // ==================================================================
  // Convenience checks (ref: http.js:99-100  is4xx)
  // ==================================================================

  is4xx(): boolean {
    return this.statusCode >= 400 && this.statusCode < 500;
  }

  is5xx(): boolean {
    return this.statusCode >= 500 && this.statusCode < 600;
  }

  /** Whether the error should be retried. */
  isRetryable(): boolean {
    return this.statusCode === 429 || this.is5xx();
  }
}
