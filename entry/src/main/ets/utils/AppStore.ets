/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Replacement for global Zotero namespace state
 *
 * ***** END LICENSE BLOCK *****
 */

export type SyncState = 'idle' | 'checking' | 'syncing' | 'downloading' | 'uploading' | 'success' | 'error' | 'offline';

/** Typed key constants for AppStorage access. */
export class StoreKeys {
  static readonly CURRENT_USER_ID        = 'zotero_currentUserId';
  static readonly CURRENT_API_KEY        = 'zotero_currentApiKey';
  static readonly SELECTED_LIBRARY_ID    = 'zotero_selectedLibraryID';
  static readonly SELECTED_COLLECTION_KEY= 'zotero_selectedCollectionKey';
  static readonly SELECTED_ITEM_KEY      = 'zotero_selectedItemKey';
  static readonly LIBRARY_REVISION       = 'zotero_libraryRevision';
  static readonly SYNC_STATUS            = 'zotero_syncStatus';
  static readonly LAST_SYNC_TIME         = 'zotero_lastSyncTime';
  static readonly THEME                  = 'zotero_theme';
}

/**
 * Global application state — wraps AppStorage for type-safe access.
 * All values are also accessible via @StorageLink('zotero_...') in @Components.
 */
export class AppStore {
  static get currentUserID(): string {
    return AppStorage.get<string>(StoreKeys.CURRENT_USER_ID) ?? '';
  }
  static set currentUserID(value: string) {
    AppStorage.setOrCreate<string>(StoreKeys.CURRENT_USER_ID, value);
  }

  static get currentApiKey(): string {
    return AppStorage.get<string>(StoreKeys.CURRENT_API_KEY) ?? '';
  }
  static set currentApiKey(value: string) {
    AppStorage.setOrCreate<string>(StoreKeys.CURRENT_API_KEY, value);
  }

  static get selectedLibraryID(): number {
    return AppStorage.get<number>(StoreKeys.SELECTED_LIBRARY_ID) ?? 0;
  }
  static set selectedLibraryID(value: number) {
    AppStorage.setOrCreate<number>(StoreKeys.SELECTED_LIBRARY_ID, value);
  }

  static get selectedCollectionKey(): string | null {
    return AppStorage.get<string>(StoreKeys.SELECTED_COLLECTION_KEY) ?? null;
  }
  static set selectedCollectionKey(value: string | null) {
    AppStorage.setOrCreate<string>(StoreKeys.SELECTED_COLLECTION_KEY, value ?? '');
  }

  static get selectedItemKey(): string | null {
    return AppStorage.get<string>(StoreKeys.SELECTED_ITEM_KEY) ?? null;
  }
  static set selectedItemKey(value: string | null) {
    AppStorage.setOrCreate<string>(StoreKeys.SELECTED_ITEM_KEY, value ?? '');
  }

  static get libraryRevision(): number {
    return AppStorage.get<number>(StoreKeys.LIBRARY_REVISION) ?? 0;
  }
  static set libraryRevision(value: number) {
    AppStorage.setOrCreate<number>(StoreKeys.LIBRARY_REVISION, value);
  }

  static get syncStatus(): SyncState {
    return (AppStorage.get<string>(StoreKeys.SYNC_STATUS) as SyncState) ?? 'idle';
  }
  static set syncStatus(value: SyncState) {
    AppStorage.setOrCreate<string>(StoreKeys.SYNC_STATUS, value);
  }

  static get lastSyncTime(): number | null {
    return AppStorage.get<number>(StoreKeys.LAST_SYNC_TIME) ?? null;
  }
  static set lastSyncTime(value: number | null) {
    AppStorage.setOrCreate<number>(StoreKeys.LAST_SYNC_TIME, value ?? 0);
  }

  static get theme(): string {
    return AppStorage.get<string>(StoreKeys.THEME) ?? 'light';
  }
  static set theme(value: string) {
    AppStorage.setOrCreate<string>(StoreKeys.THEME, value);
  }

  static initialize(): void {
    AppStorage.setOrCreate<string>(StoreKeys.CURRENT_USER_ID, '');
    AppStorage.setOrCreate<string>(StoreKeys.CURRENT_API_KEY, '');
    AppStorage.setOrCreate<number>(StoreKeys.SELECTED_LIBRARY_ID, 0);
    AppStorage.setOrCreate<string>(StoreKeys.SELECTED_COLLECTION_KEY, '');
    AppStorage.setOrCreate<string>(StoreKeys.SELECTED_ITEM_KEY, '');
    AppStorage.setOrCreate<number>(StoreKeys.LIBRARY_REVISION, 0);
    AppStorage.setOrCreate<string>(StoreKeys.SYNC_STATUS, 'idle');
    AppStorage.setOrCreate<number>(StoreKeys.LAST_SYNC_TIME, 0);
    AppStorage.setOrCreate<string>(StoreKeys.THEME, 'light');
  }
}
