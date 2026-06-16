/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: xpcom/prefs.js — user preferences persistence
 * ArkTS: @ohos.data.preferences wrapper
 *
 * ***** END LICENSE BLOCK *****
 */

import { preferences } from '@kit.ArkData';

const PREFS_NAME = 'zotero_preferences';

/** Preference keys — mirrors Zotero.Prefs namespace. */
export enum PrefKey {
  USER_ID            = 'userId',
  API_KEY            = 'apiKey',
  API_URL            = 'apiUrl',
  AUTO_SYNC_ENABLED  = 'autoSyncEnabled',
  AUTO_SYNC_INTERVAL = 'autoSyncInterval',
  FILE_SYNC_ENABLED  = 'fileSyncEnabled',
  QUICK_COPY_STYLE   = 'quickCopyStyle',
  DEFAULT_EXPORT_FORMAT = 'defaultExportFormat',
  ITEM_TREE_COLUMNS  = 'itemTreeColumns',
  ITEM_TREE_SORT     = 'itemTreeSort',
  DEBUG_LOGGING      = 'debugLogging',
  FONT_SIZE          = 'fontSize',
  UI_DENSITY         = 'uiDensity',
  LAST_SYNC_TIME     = 'lastSyncTime',
  LAST_LIBRARY_ID    = 'lastLibraryID',
  THEME              = 'theme',
}

/** Standard defaults. */
const DEFAULTS: Record<string, string | number | boolean> = {
  [PrefKey.API_URL]:                 'https://api.zotero.org',
  [PrefKey.AUTO_SYNC_ENABLED]:       true,
  [PrefKey.AUTO_SYNC_INTERVAL]:      300,     // seconds
  [PrefKey.FILE_SYNC_ENABLED]:       true,
  [PrefKey.QUICK_COPY_STYLE]:        'APA',
  [PrefKey.DEFAULT_EXPORT_FORMAT]:   'BibTeX',
  [PrefKey.ITEM_TREE_COLUMNS]:       'title,firstCreator,itemType,date,publisher,year',
  [PrefKey.ITEM_TREE_SORT]:          'title:asc',
  [PrefKey.DEBUG_LOGGING]:           false,
  [PrefKey.FONT_SIZE]:               1.0,
  [PrefKey.UI_DENSITY]:              0,       // 0=normal, 1=compact
  [PrefKey.THEME]:                   'light',
  [PrefKey.LAST_SYNC_TIME]:          0,
  [PrefKey.LAST_LIBRARY_ID]:         0,
};

/**
 * Type-safe preferences wrapper.
 *
 * Usage: await Preferences.init(context)
 *        let apiKey = await Preferences.getString(PrefKey.API_KEY)
 */
export class Preferences {
  private static prefs: preferences.Preferences | null = null;

  static async init(context: Context): Promise<void> {
    Preferences.prefs = await preferences.getPreferences(context, PREFS_NAME);
  }

  static async getString(key: PrefKey): Promise<string> {
    if (!Preferences.prefs) { throw new Error('Preferences not initialized'); }
    let def = (DEFAULTS[key] as string) ?? '';
    return (await Preferences.prefs.get(key, def)) as string;
  }

  static async getNumber(key: PrefKey): Promise<number> {
    if (!Preferences.prefs) { throw new Error('Preferences not initialized'); }
    let def = (DEFAULTS[key] as number) ?? 0;
    return (await Preferences.prefs.get(key, def)) as number;
  }

  static async getBoolean(key: PrefKey): Promise<boolean> {
    if (!Preferences.prefs) { throw new Error('Preferences not initialized'); }
    let def = (DEFAULTS[key] as boolean) ?? false;
    return (await Preferences.prefs.get(key, def)) as boolean;
  }

  static async set(key: PrefKey, value: string | number | boolean): Promise<void> {
    if (!Preferences.prefs) { throw new Error('Preferences not initialized'); }
    await Preferences.prefs.put(key, value);
    await Preferences.prefs.flush();
  }

  static async remove(key: PrefKey): Promise<void> {
    if (!Preferences.prefs) { throw new Error('Preferences not initialized'); }
    await Preferences.prefs.delete(key);
    await Preferences.prefs.flush();
  }
}
