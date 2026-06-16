/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ported from Zotero Desktop (AGPL-3.0)
 * Replaces: standalone/standalone.js + zotero.mjs initialization
 *
 * ***** END LICENSE BLOCK *****
 */

import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { AppStore } from '../utils/AppStore.ets';
import { SyncRunner } from '../sync/SyncRunner.ets';
import { ZoteroDb } from '../database/ZoteroDb.ets';
import { migrate } from '../database/SchemaMigration.ets';

const DOMAIN = 0x0001;
const PREFS_NAME = 'zotero_preferences';

export default class EntryAbility extends UIAbility {
  private syncRunner: SyncRunner | null = null;

  async onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): Promise<void> {
    hilog.info(DOMAIN, 'Zotero', 'EntryAbility onCreate');

    // 1. Initialize AppStorage defaults
    AppStore.initialize();

    // 2. Open database + run schema migration
    try {
      let db = new ZoteroDb('zotero.sqlite');
      await db.open(this.context.getApplicationContext());
      await migrate(db);
      await db.close();
      hilog.info(DOMAIN, 'Zotero', 'Database initialized successfully');
    } catch (err) {
      hilog.error(DOMAIN, 'Zotero', 'DB init failed: %{public}s', (err as Error).message);
    }

    // 3. Load saved credentials from preferences
    try {
      let prefs = await preferences.getPreferences(this.context, PREFS_NAME);
      let userId = prefs.getSync('userId', '') as string;
      let apiKey = prefs.getSync('apiKey', '') as string;
      let apiUrl = prefs.getSync('apiUrl', 'https://api.zotero.org') as string;
      let autoSyncEnabled = prefs.getSync('autoSyncEnabled', true) as boolean;
      let autoSyncInterval = prefs.getSync('autoSyncInterval', 300) as number;

      if (userId && apiKey) {
        AppStore.currentUserID = userId;
        AppStore.currentApiKey = apiKey;

        // 4. Auto-start background sync if credentials exist
        this.syncRunner = new SyncRunner(apiUrl, this.context.getApplicationContext());
        await this.syncRunner.loginWithApiKey(apiKey);
        // Silent background sync — don't block UI
        this.syncRunner.sync(true).then(() => {
          hilog.info(DOMAIN, 'Zotero', 'Background sync complete');
        });
        if (autoSyncEnabled) {
          this.syncRunner.startAutoSync(autoSyncInterval);
        }
      }
    } catch (err) {
      hilog.warn(DOMAIN, 'Zotero', 'Failed to load preferences: %{public}s', (err as Error).message);
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'Zotero', 'EntryAbility onDestroy');
    if (this.syncRunner) {
      this.syncRunner.stopAutoSync();
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'Zotero', 'onWindowStageCreate');

    // Always open MainPage — login is optional, available via settings
    windowStage.loadContent('pages/MainPage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'Zotero', 'Failed to load MainPage: %{public}s',
          JSON.stringify(err));
      }
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'Zotero', 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'Zotero', 'onForeground');
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'Zotero', 'onBackground');
  }
}
