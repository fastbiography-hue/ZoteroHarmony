/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Login page — connect Zotero account via API Key.
 * Navigated to from MainPage → "Connect" button.
 *
 * How to get an API Key:
 *   1. Go to https://www.zotero.org/settings/keys
 *   2. Click "Create New Private Key"
 *   3. Copy the generated key
 *   4. Paste it here
 *
 * ***** END LICENSE BLOCK *****
 */

import { router } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { HttpClient } from '../api/HttpClient.ets';
import { ZoteroAPI } from '../api/ZoteroAPI.ets';
import { AppStore } from '../utils/AppStore.ets';

const PREFS_NAME = 'zotero_preferences';

@Entry
@Component
struct LoginPage {
  @State apiKey: string = '';
  @State loading: boolean = false;
  @State errorMessage: string = '';

  build() {
    Column() {
      // Header
      Column() {
        Text('Connect Zotero Account')
          .fontSize(24).fontWeight(FontWeight.Bold).fontColor('#CC3333')
          .margin({ top: 60, bottom: 8 })
        Text('Enter your API Key to sync your library')
          .fontSize(15).fontColor('#666')
          .margin({ bottom: 32 })
      }
      .width('100%')

      // Form
      Column() {
        TextInput({ placeholder: 'Paste your API Key here', text: this.apiKey })
          .type(InputType.Password)
          .fontSize(16).height(48).width('100%')
          .onChange((value: string) => { this.apiKey = value; })
          .margin({ bottom: 16 })

        Button(this.loading ? 'Verifying…' : 'Connect')
          .width('100%').height(48).fontSize(17).fontWeight(FontWeight.Medium)
          .backgroundColor('#CC3333').borderRadius(8)
          .enabled(!this.loading && this.apiKey.length > 0)
          .onClick(() => { this.handleLogin(); })
      }
      .width('100%').padding({ left: 24, right: 24 })

      if (this.errorMessage) {
        Text(this.errorMessage).fontSize(14).fontColor('#CC3333')
          .textAlign(TextAlign.Center).margin({ top: 16 }).padding({ left: 24, right: 24 })
      }

      Blank()

      // Instructions
      Column() {
        Text('How to get an API Key:').fontSize(12).fontColor('#999').margin({ bottom: 4 })
        Text('1. Visit zotero.org/settings/keys').fontSize(12).fontColor('#AAA')
        Text('2. Click "Create New Private Key"').fontSize(12).fontColor('#AAA')
        Text('3. Copy and paste the key here').fontSize(12).fontColor('#AAA')
      }
      .margin({ bottom: 40 })
      .alignItems(HorizontalAlign.Start)

      Button('Skip')
        .fontSize(14).fontColor('#666').backgroundColor('#00000000')
        .onClick(() => { router.back(); })
        .margin({ bottom: 24 })
    }
    .width('100%').height('100%').backgroundColor('#FAFAFA')
  }

  private async handleLogin(): Promise<void> {
    this.loading = true;
    this.errorMessage = '';

    try {
      let http = new HttpClient('https://api.zotero.org', this.apiKey);
      let api = new ZoteroAPI(http);
      let info = await api.getKeyInfo();

      if (!info) {
        this.errorMessage = 'Invalid API Key — please check and try again';
        this.loading = false;
        return;
      }

      // Save to preferences
      let ctx = getContext(this);
      let prefs = await preferences.getPreferences(ctx, PREFS_NAME);
      await prefs.put('userId', `${info.userID}`);
      await prefs.put('apiKey', this.apiKey);
      await prefs.flush();

      // Update global state
      AppStore.currentUserID = `${info.userID}`;
      AppStore.currentApiKey = this.apiKey;

      // Go back to MainPage
      router.back();
    } catch (err) {
      this.errorMessage = 'Connection failed — check network';
      this.loading = false;
    }
  }
}
