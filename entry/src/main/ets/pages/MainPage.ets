/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Reference: chrome/content/zotero/zoteroPane.xhtml
 *
 * Three-pane layout: CollectionTree | ItemList | ItemDetail
 * Phone: single stack with tabs. Tablet: split pane.
 *
 * ***** END LICENSE BLOCK *****
 */

import { router } from '@kit.ArkUI';
import { AppStore, SyncState } from '../utils/AppStore.ets';
import { SyncRunner } from '../sync/SyncRunner.ets';
import { CollectionTree } from '../ui/tree/CollectionTree.ets';
import { CollectionTreeRow } from '../ui/tree/CollectionTreeRow.ets';
import { ItemTree } from '../ui/tree/ItemTree.ets';
import { ItemModel } from '../model/ItemModel.ets';
import { ItemPaneView, PaneView } from '../ui/ItemPaneView.ets';
import { QuickSearchBar } from '../ui/QuickSearchBar.ets';
import { ZHColor, ZHMetric } from '../theme/ThemeConstants.ets';
import { zoteroCommandRegistry } from '../commands/ZoteroCommandRegistry.ets';
import { ZoteroCommandContext, ZoteroCommands } from '../commands/ZoteroCommands.ets';
import { LibraryRepository } from '../database/LibraryRepository.ets';

/** Tab/page index for phone mode navigation. */
enum PhoneView { COLLECTIONS, ITEMS, DETAIL }

@Entry
@Component
struct MainPage {
  // Selection state
  @State selectedRowID: string = 'L1';
  @State selectedCollectionKey: string = '';
  @State selectedViewMode: string = 'collection';
  @State selectedItemKey: string = '';
  @State selectedItemKeys: string[] = [];
  @State selectedView: PaneView = 'details';
  @State phoneView: PhoneView = PhoneView.COLLECTIONS;
  // Item detail
  @State currentItem: ItemModel = new ItemModel();
  @State loggedIn: boolean = false;
  @State searchText: string = '';
  @StorageLink('zotero_libraryRevision') revision: number = 0;
  @State syncStatus: SyncState = 'idle';
  @State collectionDialogVisible: boolean = false;
  @State collectionDialogTitle: string = '';
  @State collectionDialogValue: string = '';
  @State collectionDialogMode: string = '';
  @State collectionDialogTargetKey: string = '';
  @State collectionDialogTargetType: string = '';
  @StorageLink('zotero_theme') themeMode: string = 'light';
  private syncRunner: SyncRunner | null = null;

  aboutToAppear(): void {
    let apiKey = AppStore.currentApiKey;
    this.loggedIn = !!apiKey;
    this.syncStatus = AppStore.syncStatus;
    this.themeMode = AppStore.theme;
    if (apiKey) {
      this.syncRunner = new SyncRunner('https://api.zotero.org', getContext(this).getApplicationContext());
      this.syncRunner.loginWithApiKey(apiKey);
    }
  }

  build() {
    Stack() {
      Column() {
      // ======== Toolbar ========
      Row() {
        // Show collections sidebar toggle on phone
        Button('☰').fontSize(18).width(ZHMetric.HIT_TARGET).height(ZHMetric.HIT_TARGET)
          .backgroundColor(ZHColor.TRANSPARENT)
          .onClick(() => { this.phoneView = PhoneView.COLLECTIONS; })

        Column() {
          Text('Zotero Harmony')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.phoneView === PhoneView.COLLECTIONS ? 'Collections and libraries' :
            (this.phoneView === PhoneView.ITEMS ?
              (this.searchText.length > 0 ? `Filtered by "${this.searchText}"` : 'Items in selected collection') :
            'Metadata, files, notes, and links'))
            .fontSize(11)
            .fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .margin({ left: 6 })

        Button('+').fontSize(20).width(ZHMetric.HIT_TARGET).height(ZHMetric.HIT_TARGET)
          .backgroundColor(ZHColor.BRAND).fontColor(ZHColor.TEXT_INVERSE).borderRadius(20)
          .margin({ right: 6 })
          .onClick(() => { this._executeCommand(ZoteroCommands.NEW_ITEM); })

        Button('Import').fontSize(12).height(36)
          .margin({ right: 6 })
          .backgroundColor(this.themeMode === 'dark' ? '#242A33' : ZHColor.SURFACE_ALT)
          .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
          .onClick(() => { this._executeCommand(ZoteroCommands.IMPORT); })

        Button('ID').fontSize(12).height(36)
          .margin({ right: 6 })
          .backgroundColor(this.themeMode === 'dark' ? '#242A33' : ZHColor.SURFACE_ALT)
          .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
          .onClick(() => { this._executeCommand(ZoteroCommands.ADD_BY_IDENTIFIER); })

        Button('Note').fontSize(12).height(36)
          .margin({ right: 6 })
          .backgroundColor(this.themeMode === 'dark' ? '#242A33' : ZHColor.SURFACE_ALT)
          .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
          .enabled(this.selectedItemKeys.length > 0)
          .onClick(() => { this._executeCommand(ZoteroCommands.NEW_NOTE); })

        Button('Prefs').fontSize(12).height(36)
          .margin({ right: 6 })
          .backgroundColor(this.themeMode === 'dark' ? '#242A33' : ZHColor.SURFACE_ALT)
          .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
          .onClick(() => { this._executeCommand(ZoteroCommands.SHOW_PREFERENCES); })

        Button('⌕').fontSize(18).width(ZHMetric.HIT_TARGET).height(ZHMetric.HIT_TARGET)
          .backgroundColor(ZHColor.TRANSPARENT)
          .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
          .onClick(() => {
            router.pushUrl({ url: 'pages/SearchPage' });
          })
      }
      .width('100%').height(ZHMetric.TOOLBAR_HEIGHT)
      .backgroundColor(this.themeMode === 'dark' ? '#1B2028' : ZHColor.SURFACE_RAISED)
      .border({ width: { bottom: 1 }, color: this.themeMode === 'dark' ? '#303846' : ZHColor.BORDER })
      .padding({ left: 8, right: 10 })

      // ======== Three-pane content ========
      Row() {
        // LEFT — Collection Tree (phone: full screen, tablet: ~25%)
        Column() {
          Row() {
            Text('LIBRARY')
              .fontSize(11)
              .fontColor(ZHColor.TEXT_MUTED)
              .fontWeight(FontWeight.Bold)
              .layoutWeight(1)
            Button('+')
              .fontSize(16)
              .width(32)
              .height(30)
              .backgroundColor(ZHColor.TRANSPARENT)
              .fontColor(ZHColor.TEXT_MUTED)
              .onClick(() => { this._executeCommand(ZoteroCommands.NEW_COLLECTION); })
          }
          .width('100%')
          .height(ZHMetric.HEADER_HEIGHT)
          .padding({ left: 14, right: 8 })

          CollectionTree({
            selectedRowID: $selectedRowID,
            revision: this.revision,
            onRowSelected: (row: CollectionTreeRow) => {
              this.selectedCollectionKey = (row.type === 'collection' || row.type === 'search') ? (row.key ?? '') : '';
              this.selectedViewMode = row.type;
              this.selectedItemKey = '';
              this.selectedItemKeys = [];
              this.currentItem = new ItemModel();
              this.phoneView = PhoneView.ITEMS;
            },
            onRowAction: (action: string, row: CollectionTreeRow) => {
              this._handleCollectionAction(action, row);
            },
          })
          .layoutWeight(1)
        }
        .width('27%')
        .backgroundColor(this.themeMode === 'dark' ? '#171B22' : ZHColor.SURFACE_SIDEBAR)
        .border({ width: { right: 1 }, color: this.themeMode === 'dark' ? '#303846' : ZHColor.BORDER })

        // CENTER — Item List
        Column() {
          // Quick search
      Row() {
        QuickSearchBar({
          inputText: $searchText,
          placeholder: 'Search title, creator, year',
          onSearch: (text: string) => { this.searchText = text; },
        })
        .layoutWeight(1)
      }
          .width('100%')
          .padding({ left: 10, right: 10, top: 7, bottom: 7 })
          .backgroundColor(this.themeMode === 'dark' ? '#11151B' : ZHColor.SURFACE)
          .border({ width: { bottom: 1 }, color: this.themeMode === 'dark' ? '#252C38' : ZHColor.BORDER_SOFT })

          ItemTree({
            selectedItemKey: $selectedItemKey,
            selectedItemKeys: $selectedItemKeys,
            collectionKey: this.selectedCollectionKey,
            filterText: this.searchText,
            revision: this.revision,
            viewMode: this.selectedViewMode,
            onItemSelected: (item: ItemModel) => {
              this.currentItem = item;
              this.phoneView = PhoneView.DETAIL;
            },
            onItemAction: (action: string, item: ItemModel) => {
              this.currentItem = item;
              this.phoneView = PhoneView.DETAIL;
              if (action === 'open') {
                this.selectedItemKey = item.key ?? '';
                this.selectedItemKeys = [this.selectedItemKey];
                this.currentItem = item;
                if (item.isAttachment()) {
                  this._executeCommand(ZoteroCommands.OPEN_READER);
                }
                return;
              }
              if (action === 'citation') {
                this._executeCommand(ZoteroCommands.COPY_CITATION);
                return;
              }
              if (action === 'bibliography') {
                this._executeCommand(ZoteroCommands.COPY_BIBLIOGRAPHY);
                return;
              }
              if (action === 'note') {
                this._executeCommand(ZoteroCommands.NEW_NOTE);
                return;
              }
              if (action === 'attachment') {
                this._executeCommand(ZoteroCommands.ADD_ATTACHMENT);
                return;
              }
              if (action === 'addToCollection') {
                this._executeCommand(ZoteroCommands.ADD_TO_COLLECTION);
                return;
              }
              if (action === 'restore') {
                this._executeCommand(ZoteroCommands.RESTORE);
                return;
              }
              if (action === 'delete') {
                this._executeCommand(ZoteroCommands.DELETE);
                return;
              }
            },
          })
          .layoutWeight(1)
        }
        .width('43%')
        .backgroundColor(this.themeMode === 'dark' ? '#11151B' : ZHColor.SURFACE)
        .border({ width: { right: 1 }, color: this.themeMode === 'dark' ? '#303846' : ZHColor.BORDER })

        // RIGHT — Item Detail
        Column() {
          Row() {
            Text(this.selectedItemKeys.length > 1 ? `${this.selectedItemKeys.length} Items Selected` : (this.currentItem.itemData.get('title') ?? 'Item Details'))
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Button('Open')
              .fontSize(12)
              .height(30)
              .margin({ left: 8 })
              .enabled(this.selectedItemKey.length > 0)
              .onClick(() => { this._executeCommand(ZoteroCommands.OPEN_READER); })
            Button('Cite')
              .fontSize(12)
              .height(30)
              .margin({ left: 6 })
              .enabled(this.selectedItemKeys.length > 0)
              .onClick(() => { this._executeCommand(ZoteroCommands.COPY_CITATION); })
            Button('Bib')
              .fontSize(12)
              .height(30)
              .margin({ left: 6 })
              .enabled(this.selectedItemKeys.length > 0)
              .onClick(() => { this._executeCommand(ZoteroCommands.COPY_BIBLIOGRAPHY); })
            Button('Export')
              .fontSize(12)
              .height(30)
              .margin({ left: 6 })
              .enabled(this.selectedItemKeys.length > 0)
              .onClick(() => { this._executeCommand(ZoteroCommands.EXPORT); })
            Button('Merge')
              .fontSize(12)
              .height(30)
              .margin({ left: 6 })
              .enabled(this.selectedViewMode === 'duplicates' && this.selectedItemKeys.length > 1)
              .backgroundColor(ZHColor.BRAND_SOFT)
              .fontColor(ZHColor.BRAND)
              .onClick(() => { this._executeCommand(ZoteroCommands.DUPLICATE_MERGE); })
            Button('Attach')
              .fontSize(12)
              .height(30)
              .margin({ left: 6 })
              .enabled(this.selectedItemKey.length > 0)
              .onClick(() => { this._executeCommand(ZoteroCommands.ADD_ATTACHMENT); })
            Button('Add')
              .fontSize(12)
              .height(30)
              .margin({ left: 6 })
              .enabled(this.selectedItemKeys.length > 0 && this.selectedViewMode !== 'trash')
              .onClick(() => { this._executeCommand(ZoteroCommands.ADD_TO_COLLECTION); })
            Button(this.selectedViewMode === 'trash' ? 'Restore' : 'Delete')
              .fontSize(12)
              .height(30)
              .margin({ left: 6 })
              .enabled(this.selectedItemKeys.length > 0)
              .backgroundColor(ZHColor.BRAND_SOFT)
              .fontColor(ZHColor.BRAND)
              .onClick(() => { this._executeCommand(this.selectedViewMode === 'trash' ? ZoteroCommands.RESTORE : ZoteroCommands.DELETE); })
          }
          .width('100%')
          .height(40)
          .padding({ left: 14, right: 12 })
          .backgroundColor(this.themeMode === 'dark' ? '#11151B' : ZHColor.SURFACE)
          .border({ width: { bottom: 1 }, color: this.themeMode === 'dark' ? '#252C38' : ZHColor.BORDER_SOFT })

          ItemPaneView({
            item: $currentItem,
            selectedView: $selectedView,
          })
          .layoutWeight(1)
        }
        .layoutWeight(1)
        .backgroundColor(this.themeMode === 'dark' ? '#11151B' : ZHColor.SURFACE)
      }
      .layoutWeight(1)

      // ======== Footer — sync status ========
      Row() {
        Circle({ width: 8, height: 8 })
          .fill(this.syncStatus === 'error' ? ZHColor.BRAND :
            (this.syncStatus === 'syncing' || this.syncStatus === 'checking' || this.syncStatus === 'downloading' || this.syncStatus === 'uploading' ?
              ZHColor.WARNING : (this.loggedIn ? ZHColor.SUCCESS : ZHColor.TEXT_SUBTLE)))
          .margin({ right: 6 })

        if (this.loggedIn) {
          Text(this.syncStatus === 'idle' ? 'Ready to sync' :
            (this.syncStatus === 'checking' ? 'Checking libraries' :
              (this.syncStatus === 'syncing' ? 'Syncing library' :
                (this.syncStatus === 'downloading' ? 'Downloading changes' :
                  (this.syncStatus === 'uploading' ? 'Uploading local changes' :
                    (this.syncStatus === 'success' ? 'Sync complete' :
                      (this.syncStatus === 'offline' ? 'Offline' : 'Sync error')))))))
            .fontSize(12).fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
          Blank()
          Button('Sync').fontSize(12).height(28)
            .enabled(this.syncStatus !== 'syncing' && this.syncStatus !== 'checking')
            .onClick(() => { this._doSync(); })
        } else {
          Text('Not connected').fontSize(12).fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
          Blank()
          Button('Connect').fontSize(12).height(28)
            .backgroundColor(ZHColor.BRAND)
            .fontColor(ZHColor.TEXT_INVERSE)
            .onClick(() => { router.pushUrl({ url: 'pages/LoginPage' }); })
        }
      }
      .width('100%').height(ZHMetric.STATUS_HEIGHT)
      .padding({ left: 12, right: 12 })
      .backgroundColor(this.themeMode === 'dark' ? '#1B2028' : ZHColor.SURFACE_RAISED)
      .border({ width: { top: 1 }, color: this.themeMode === 'dark' ? '#303846' : ZHColor.BORDER })
    }
      if (this.collectionDialogVisible) {
        Column() {
          Blank().layoutWeight(1)
          Column() {
            Text(this.collectionDialogTitle)
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
              .margin({ bottom: 10 })
            TextInput({ placeholder: 'Name', text: this.collectionDialogValue })
              .fontSize(14)
              .height(38)
              .width('100%')
              .onChange((value: string) => { this.collectionDialogValue = value; })
            Row() {
              Button('Cancel').fontSize(12).height(32)
                .onClick(() => { this.collectionDialogVisible = false; })
              Blank()
              Button('OK').fontSize(12).height(32)
                .backgroundColor(ZHColor.BRAND)
                .fontColor(ZHColor.TEXT_INVERSE)
                .onClick(() => { this._submitCollectionDialog(); })
            }
            .width('100%')
            .margin({ top: 12 })
          }
          .width('70%')
          .padding(16)
          .backgroundColor(this.themeMode === 'dark' ? '#1B2028' : ZHColor.SURFACE_RAISED)
          .borderRadius(10)
        }
        .width('100%').height('100%')
        .backgroundColor('#80000000')
      }
    }
    .width('100%').height('100%')
    .backgroundColor(this.themeMode === 'dark' ? '#11151B' : ZHColor.SURFACE)
  }

  private _doSync(): void {
    if (this.syncRunner) {
      this.syncStatus = 'checking';
      AppStore.syncStatus = 'checking';
      this.syncRunner.sync(false).then((ok: boolean) => {
        this.syncStatus = ok ? 'success' : 'error';
        AppStore.syncStatus = this.syncStatus;
        if (!ok && this.syncRunner) {
          AppStore.lastSyncTime = this.syncRunner.syncStatus.lastSyncTimestamp;
        }
      }).catch((_err: Error) => {
        this.syncStatus = 'error';
        AppStore.syncStatus = 'error';
      });
    }
  }

  private _executeCommand(commandID: string): void {
    zoteroCommandRegistry.execute(commandID, this._commandContext()).then(() => {
      if (commandID === ZoteroCommands.DELETE || commandID === ZoteroCommands.RESTORE || commandID === ZoteroCommands.DUPLICATE_MERGE) {
        this.selectedItemKey = '';
        this.selectedItemKeys = [];
        this.currentItem = new ItemModel();
      }
    }).catch((_err: Error) => {
    });
  }

  private _handleCollectionAction(action: string, row: CollectionTreeRow): void {
    this.selectedRowID = row.id;
    this.selectedCollectionKey = row.key ?? '';
    this.selectedViewMode = row.type;
    if (row.type === 'search' && action === 'new-child') {
      return;
    }
    if (action === 'rename') {
      this.collectionDialogMode = 'rename';
      this.collectionDialogTargetKey = row.key ?? '';
      this.collectionDialogTargetType = row.type;
      this.collectionDialogTitle = row.type === 'search' ? 'Rename Saved Search' : 'Rename Collection';
      this.collectionDialogValue = row.name;
      this.collectionDialogVisible = true;
      return;
    }
    if (action === 'new-child') {
      this.collectionDialogMode = 'new-child';
      this.collectionDialogTargetKey = row.key ?? '';
      this.collectionDialogTargetType = row.type;
      this.collectionDialogTitle = 'New Child Collection';
      this.collectionDialogValue = '';
      this.collectionDialogVisible = true;
      return;
    }
    if (action === 'delete' && row.key) {
      let repo = new LibraryRepository();
      repo.open(getContext(this).getApplicationContext()).then(() => {
        if (row.type === 'search') {
          return repo.deleteSavedSearch(row.key ?? '');
        }
        return repo.deleteCollection(row.key ?? '');
      }).then(() => {
        this.selectedRowID = 'L1';
        this.selectedCollectionKey = '';
        this.selectedViewMode = 'collection';
        this.selectedItemKey = '';
        this.selectedItemKeys = [];
        this.currentItem = new ItemModel();
        this.revision++;
        repo.close();
      }).catch((_err: Error) => {
        repo.close();
      });
    }
  }

  private _submitCollectionDialog(): void {
    let repo = new LibraryRepository();
    let title = this.collectionDialogValue.trim();
    if (title.length === 0) {
      this.collectionDialogVisible = false;
      return;
    }
    repo.open(getContext(this).getApplicationContext()).then(() => {
      if (this.collectionDialogMode === 'rename' && this.collectionDialogTargetKey.length > 0) {
        if (this.collectionDialogTargetType === 'search') {
          return repo.renameSavedSearch(this.collectionDialogTargetKey, title);
        }
        return repo.renameCollection(this.collectionDialogTargetKey, title);
      }
      if (this.collectionDialogMode === 'new-child') {
        return repo.createCollection(title, this.collectionDialogTargetKey.length > 0 ? this.collectionDialogTargetKey : null).then(() => {});
      }
      return Promise.resolve();
    }).then(() => {
      this.collectionDialogVisible = false;
      this.collectionDialogMode = '';
      this.collectionDialogTargetKey = '';
      this.collectionDialogTargetType = '';
      this.collectionDialogTitle = '';
      this.collectionDialogValue = '';
      this.revision++;
      repo.close();
    }).catch((_err: Error) => {
      this.collectionDialogVisible = false;
      this.collectionDialogMode = '';
      this.collectionDialogTargetKey = '';
      this.collectionDialogTargetType = '';
      this.collectionDialogTitle = '';
      this.collectionDialogValue = '';
      repo.close();
    });
  }

  private _commandContext(): ZoteroCommandContext {
    return {
      appContext: getContext(this).getApplicationContext(),
      libraryID: 1,
      collectionKey: this.selectedCollectionKey,
      itemKey: this.selectedItemKey,
      itemKeys: this.selectedItemKeys,
      viewMode: this.selectedViewMode,
      hasSelection: this.selectedItemKeys.length > 0,
      onLibraryChanged: (): void => {
        this.revision++;
      },
    };
  }
}
