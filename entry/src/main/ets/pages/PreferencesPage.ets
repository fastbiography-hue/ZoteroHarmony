/*
 * Preferences page aligned with Zotero Desktop settings categories.
 */

import { router } from '@kit.ArkUI';
import { ZHColor, ZHMetric } from '../theme/ThemeConstants.ets';
import { Preferences, PrefKey } from '../utils/Preferences.ets';
import { AppStore } from '../utils/AppStore.ets';

type PreferenceTab = 'general' | 'sync' | 'cite' | 'export' | 'advanced';

@Entry
@Component
struct PreferencesPage {
  @State selectedTab: PreferenceTab = 'general';
  @State autoSync: boolean = true;
  @State autoSyncInterval: number = 300;
  @State fileSync: boolean = true;
  @State quickCopyStyle: string = 'APA';
  @State exportFormat: string = 'BibTeX';
  @State debugLogging: boolean = false;
  @State itemTreeColumns: string = '';
  @State itemTreeSort: string = '';
  @StorageLink('zotero_theme') themeMode: string = 'light';

  aboutToAppear(): void {
    Preferences.init(getContext(this).getApplicationContext()).then(() => {
      return Preferences.getBoolean(PrefKey.AUTO_SYNC_ENABLED);
    }).then((value: boolean) => {
      this.autoSync = value;
      return Preferences.getNumber(PrefKey.AUTO_SYNC_INTERVAL);
    }).then((value: number) => {
      this.autoSyncInterval = value;
      return Preferences.getBoolean(PrefKey.FILE_SYNC_ENABLED);
    }).then((value: boolean) => {
      this.fileSync = value;
      return Preferences.getString(PrefKey.QUICK_COPY_STYLE);
    }).then((value: string) => {
      this.quickCopyStyle = value;
      return Preferences.getString(PrefKey.DEFAULT_EXPORT_FORMAT);
    }).then((value: string) => {
      this.exportFormat = value;
      return Preferences.getBoolean(PrefKey.DEBUG_LOGGING);
    }).then((value: boolean) => {
      this.debugLogging = value;
      return Preferences.getString(PrefKey.ITEM_TREE_COLUMNS);
    }).then((value: string) => {
      this.itemTreeColumns = value;
      return Preferences.getString(PrefKey.ITEM_TREE_SORT);
    }).then((value: string) => {
      this.itemTreeSort = value;
      return Preferences.getString(PrefKey.THEME);
    }).then((value: string) => {
      this.themeMode = value.length > 0 ? value : 'light';
      AppStore.theme = this.themeMode;
    }).catch((_err: Error) => {});
  }

  build() {
    Row() {
      Column() {
        Row() {
          Button('‹')
            .fontSize(24)
            .width(40)
            .height(40)
            .backgroundColor(ZHColor.TRANSPARENT)
            .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
            .onClick(() => { router.back(); })
          Text('Preferences')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
            .layoutWeight(1)
        }
        .height(ZHMetric.TOOLBAR_HEIGHT)
        .padding({ left: 8, right: 10 })
        .border({ width: { bottom: 1 }, color: this.themeMode === 'dark' ? '#303846' : ZHColor.BORDER })

        this._tabButton('general', 'General')
        this._tabButton('sync', 'Sync')
        this._tabButton('cite', 'Cite')
        this._tabButton('export', 'Export')
        this._tabButton('advanced', 'Advanced')
        Blank().layoutWeight(1)
      }
      .width(168)
      .height('100%')
      .backgroundColor(this.themeMode === 'dark' ? '#171B22' : ZHColor.SURFACE_SIDEBAR)
      .border({ width: { right: 1 }, color: this.themeMode === 'dark' ? '#303846' : ZHColor.BORDER })

      Scroll() {
        Column() {
          if (this.selectedTab === 'general') {
            this._sectionTitle('General')
            this._settingText('Appearance', this.themeMode === 'dark' ? 'Dark' : 'Light')
            Row() {
              this._themeButton('light', 'Light')
              this._themeButton('dark', 'Dark')
            }
            .height(46)
            .width('100%')
            .border({ width: { bottom: 1 }, color: this.themeMode === 'dark' ? '#252C38' : ZHColor.BORDER_SOFT })
            this._settingToggle('Open last library on start', true)
            this._settingToggle('Automatically recognize PDF metadata', true)
            this._settingText('Language', 'System')
          } else if (this.selectedTab === 'sync') {
            this._sectionTitle('Sync')
            this._settingToggle('Auto-sync', this.autoSync, PrefKey.AUTO_SYNC_ENABLED)
            this._settingInterval('Sync interval', this.autoSyncInterval)
            this._settingToggle('Sync attachment files', this.fileSync, PrefKey.FILE_SYNC_ENABLED)
            this._settingText('Account', 'Connect from main toolbar')
          } else if (this.selectedTab === 'cite') {
            this._sectionTitle('Cite')
            this._settingText('Quick Copy style', this.quickCopyStyle)
            this._settingText('Locale', 'en-US')
            this._settingToggle('Copy bibliography as plain text', true)
          } else if (this.selectedTab === 'export') {
            this._sectionTitle('Export')
            this._settingText('Default format', this.exportFormat)
            this._settingToggle('Include notes', true)
            this._settingToggle('Include files when available', false)
          } else {
            this._sectionTitle('Advanced')
            this._settingToggle('Debug logging', this.debugLogging, PrefKey.DEBUG_LOGGING)
            this._settingText('Item columns', this.itemTreeColumns.length > 0 ? this.itemTreeColumns : 'default')
            this._settingText('Item sort', this.itemTreeSort.length > 0 ? this.itemTreeSort : 'title:asc')
            this._settingText('Database', 'zotero.sqlite')
            this._settingText('Schema', 'Local Zotero-compatible baseline')
          }
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 18, bottom: 32 })
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor(this.themeMode === 'dark' ? '#11151B' : ZHColor.SURFACE)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.themeMode === 'dark' ? '#11151B' : ZHColor.SURFACE)
  }

  @Builder
  _tabButton(tab: PreferenceTab, label: string) {
    Text(label)
      .fontSize(14)
      .fontWeight(this.selectedTab === tab ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.selectedTab === tab ? (this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT) : (this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED))
      .height(38)
      .width('100%')
      .padding({ left: 18, right: 12 })
      .backgroundColor(this.selectedTab === tab ? (this.themeMode === 'dark' ? '#263247' : ZHColor.SELECTED_STRONG) : ZHColor.TRANSPARENT)
      .onClick(() => { this.selectedTab = tab; })
  }

  @Builder
  _sectionTitle(title: string) {
    Text(title)
      .fontSize(22)
      .fontWeight(FontWeight.Bold)
      .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
      .width('100%')
      .margin({ bottom: 18 })
  }

  @Builder
  _settingToggle(label: string, value: boolean, key?: PrefKey) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: value })
        .onChange((isOn: boolean) => {
          this._setBooleanPreference(key, isOn);
        })
    }
    .height(48)
    .width('100%')
    .border({ width: { bottom: 1 }, color: this.themeMode === 'dark' ? '#252C38' : ZHColor.BORDER_SOFT })
  }

  @Builder
  _settingInterval(label: string, value: number) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
        .layoutWeight(1)
      Row() {
        this._intervalButton(300, '5m', value)
        this._intervalButton(900, '15m', value)
        this._intervalButton(3600, '1h', value)
      }
    }
    .height(48)
    .width('100%')
    .border({ width: { bottom: 1 }, color: this.themeMode === 'dark' ? '#252C38' : ZHColor.BORDER_SOFT })
  }

  @Builder
  _settingText(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(15)
        .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
        .layoutWeight(1)
      Text(value)
        .fontSize(14)
        .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .height(48)
    .width('100%')
    .border({ width: { bottom: 1 }, color: this.themeMode === 'dark' ? '#252C38' : ZHColor.BORDER_SOFT })
  }

  private _setBooleanPreference(key: PrefKey | undefined, value: boolean): void {
    if (!key) {
      return;
    }
    if (key === PrefKey.AUTO_SYNC_ENABLED) {
      this.autoSync = value;
    } else if (key === PrefKey.FILE_SYNC_ENABLED) {
      this.fileSync = value;
    } else if (key === PrefKey.DEBUG_LOGGING) {
      this.debugLogging = value;
    }
    Preferences.set(key, value).then(() => {}).catch((_err: Error) => {});
  }

  @Builder
  _intervalButton(value: number, label: string, currentValue: number) {
    Button(label)
      .fontSize(12)
      .height(30)
      .margin({ left: 6 })
      .backgroundColor(currentValue === value ? ZHColor.BRAND : (this.themeMode === 'dark' ? '#242A33' : ZHColor.SURFACE_ALT))
      .fontColor(currentValue === value ? ZHColor.TEXT_INVERSE : (this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT))
      .onClick(() => { this._setNumberPreference(PrefKey.AUTO_SYNC_INTERVAL, value); })
  }

  @Builder
  _themeButton(value: string, label: string) {
    Button(label)
      .fontSize(12)
      .height(32)
      .margin({ right: 8 })
      .backgroundColor(this.themeMode === value ? ZHColor.BRAND : (this.themeMode === 'dark' ? '#242A33' : ZHColor.SURFACE_ALT))
      .fontColor(this.themeMode === value ? ZHColor.TEXT_INVERSE : (this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT))
      .onClick(() => { this._setThemePreference(value); })
  }

  private _setThemePreference(value: string): void {
    this.themeMode = value;
    AppStore.theme = value;
    Preferences.set(PrefKey.THEME, value).then(() => {}).catch((_err: Error) => {});
  }

  private _setNumberPreference(key: PrefKey, value: number): void {
    if (key === PrefKey.AUTO_SYNC_INTERVAL) {
      this.autoSyncInterval = value;
    }
    Preferences.set(key, value).then(() => {}).catch((_err: Error) => {});
  }
}
