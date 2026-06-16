/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ported from Zotero Desktop (AGPL-3.0)
 *
 * Ref: xpcom/sync/syncExceptions.js (UserCancelledException)
 * Ref: xpcom/sync/syncEngine.js (UPLOAD_RESULT_* / DOWNLOAD_RESULT_*)
 *
 * ***** END LICENSE BLOCK *****
 */

/**
 * Download engine result codes.
 * Ref: syncEngine.js:81-85
 */
export enum DownloadResult {
  CONTINUE               = 1,
  CHANGES_TO_UPLOAD      = 2,
  NO_CHANGES_TO_UPLOAD   = 3,
  LIBRARY_UNMODIFIED     = 4,
  RESTART                = 5,
}

/**
 * Upload engine result codes.
 * Ref: syncEngine.js:87-92
 */
export enum UploadResult {
  SUCCESS            = 1,
  NOTHING_TO_UPLOAD  = 2,
  LIBRARY_CONFLICT   = 3,
  OBJECT_CONFLICT    = 4,
  RESTART            = 5,
  CANCEL             = 6,
}

/**
 * User cancelled the sync operation.
 * Ref: syncExceptions.js:32-35
 */
export class UserCancelledException extends Error {
  /** If true, advance to next library; if false, stop sync completely. */
  readonly advanceToNextLibrary: boolean;

  constructor(advanceToNextLibrary: boolean = false) {
    super('User cancelled sync');
    this.name = 'UserCancelledException';
    this.advanceToNextLibrary = advanceToNextLibrary;
  }
}

/**
 * Server-side library version went backward (e.g. account delete+undelete).
 * Triggers a full-sync reset.
 * Ref: syncEngine.js:105  ZoteroLibraryVersionDecreaseError
 */
export class LibraryVersionDecreaseError extends Error {
  readonly libraryName: string;

  constructor(libraryName: string, detail: string) {
    super(`Library version went backward for ${libraryName}: ${detail}`);
    this.name = 'LibraryVersionDecreaseError';
    this.libraryName = libraryName;
  }
}
