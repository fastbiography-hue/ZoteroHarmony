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
import { preferences } from '@kit.ArkData';
import { LibraryRepository, PendingSyncSummary } from '../database/LibraryRepository.ets';
import { IdentifierLookup } from '../import/IdentifierLookup.ets';

/** Tab/page index for phone mode navigation. */
enum PhoneView { COLLECTIONS, ITEMS, DETAIL }

class IdentifierCreateEntry {
  idType: string = '';
  value: string = '';
  itemType: string = '';
  fieldName: string = '';
  title: string = '';
}

const ITEM_TYPE_OPTIONS: [string, string][] = [
  ['Journal', 'journalArticle'], ['Book', 'book'], ['Book Sect.', 'bookSection'],
  ['Conf.', 'conferencePaper'], ['Thesis', 'thesis'], ['Report', 'report'], ['Web Page', 'webpage'],
];

function formatPendingSyncSummary(summary: PendingSyncSummary): string {
  let total = summary.queueCount + summary.deleteCount;
  if (total === 0) { return ''; }
  if (summary.deleteCount === 0) { return `${summary.queueCount} changes pending`; }
  if (summary.queueCount === 0) { return `${summary.deleteCount} deletions pending`; }
  return `${summary.queueCount} changes, ${summary.deleteCount} deletions`;
}

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
  @State collectionDialogError: string = '';
  @State collectionDialogMode: string = '';
  @State collectionDialogTargetKey: string = '';
  @State collectionDialogTargetType: string = '';
  // New Item dialog
  @State newItemDialogVisible: boolean = false;
  @State newItemDialogType: string = 'journalArticle';
  @State newItemDialogTitle: string = '';
  // Add by Identifier dialog
  @State identifierDialogVisible: boolean = false;
  @State identifierDialogText: string = '';
  @State identifierDialogError: string = '';
  @StorageLink('zotero_theme') themeMode: string = 'light';
  @State pendingSyncMap: Record<string, boolean> = {};
  @State pendingSyncSummaryText: string = '';
  @State pendingSyncRevision: number = 0;
  @State syncErrorMessage: string = '';
  @State authReady: boolean = false;
  @State authLoading: boolean = false;
  private syncRunner: SyncRunner | null = null;

  aboutToAppear(): void {
    this.themeMode = AppStore.theme;
    this._loadAuthState().catch((_err: Error) => {});
    this._refreshPendingSyncState();
  }

  /**
   * Called when page becomes visible (e.g. returning from LoginPage).
   * Re-reads auth state so the footer updates immediately.
   */
  onPageShow(): void {
    this._loadAuthState().catch((_err: Error) => {});
  }

  /**
   * Restore login state: AppStore first, then preferences fallback.
   * Awaits auth init so authReady reflects real state.
   */
  private async _loadAuthState(): Promise<void> {
    let apiKey = AppStore.currentApiKey;
    if (!apiKey) {
      // Try preferences fallback (app restart scenario)
      let ctx = getContext(this).getApplicationContext();
      try {
        let prefs = await preferences.getPreferences(ctx, 'zotero_preferences');
        let savedKey = prefs.getSync('apiKey', '') as string;
        let savedUserID = prefs.getSync('userId', '') as string;
        if (savedKey.length > 0) {
          AppStore.currentApiKey = savedKey;
          AppStore.currentUserID = savedUserID;
          apiKey = savedKey;
        }
      } catch (_err) { /* preferences unavailable */ }
    }
    if (!apiKey) {
      this.loggedIn = false;
      this.authReady = false;
      this.authLoading = false;
      return;
    }
    await this._initSyncRunner(apiKey);
  }

  /**
   * Initialize SyncRunner and await loginWithApiKey completion.
   * This avoids the race where _doSync fires before the API key
   * is written to SyncLocalState.
   */
  private async _initSyncRunner(apiKey: string): Promise<void> {
    this.authLoading = true;
    this.authReady = false;
    this.loggedIn = true;

    if (!this.syncRunner) {
      this.syncRunner = new SyncRunner('https://api.zotero.org',
        getContext(this).getApplicationContext());
    }

    try {
      await this.syncRunner.loginWithApiKey(apiKey);
      this.authReady = true;
      this.syncStatus = 'idle';
      this.syncErrorMessage = '';
    } catch (_err) {
      this.authReady = false;
      this.loggedIn = false;
      this.syncStatus = 'error';
      this.syncErrorMessage = 'Failed to initialize Zotero auth';
    } finally {
      this.authLoading = false;
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
          .onClick(() => { this.newItemDialogVisible = true; })

        Button('Import').fontSize(12).height(36)
          .margin({ right: 6 })
          .backgroundColor(this.themeMode === 'dark' ? '#242A33' : ZHColor.SURFACE_ALT)
          .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
          .onClick(() => { this._executeCommand(ZoteroCommands.IMPORT); })

        Button('ID').fontSize(12).height(36)
          .margin({ right: 6 })
          .backgroundColor(this.themeMode === 'dark' ? '#242A33' : ZHColor.SURFACE_ALT)
          .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
          .onClick(() => { this.identifierDialogVisible = true; })

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
              .onClick(() => {
                this.collectionDialogMode = 'new';
                this.collectionDialogTargetKey = '';
                this.collectionDialogTitle = 'New Collection';
                this.collectionDialogValue = '';
                this.collectionDialogError = '';
                this.collectionDialogVisible = true;
              })
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
              // Child-row actions from ItemTree hierarchy
              if (action === 'openAttachment') {
                this.selectedItemKey = item.key ?? '';
                this.selectedItemKeys = [this.selectedItemKey];
                this.currentItem = item;
                this.selectedView = 'details'; // attachment detail form in ItemPaneView
                if (item.isAttachment()) {
                  this._executeCommand(ZoteroCommands.OPEN_READER);
                }
                return;
              }
              if (action === 'editNote') {
                this.selectedItemKey = item.key ?? '';
                this.selectedItemKeys = [this.selectedItemKey];
                this.currentItem = item;
                this.selectedView = 'note'; // triggers note editor in ItemPaneView
                return;
              }
              if (action === 'deleteChild') {
                this.selectedItemKey = item.key ?? '';
                this.selectedItemKeys = [this.selectedItemKey];
                this.currentItem = item;
                if (item.isNote() || item.isAttachment()) {
                  this._executeCommand(ZoteroCommands.DELETE);
                }
                this.revision++;
                return;
              }
              if (action === 'openAnnotation') {
                this.selectedItemKey = item.key ?? '';
                this.selectedItemKeys = [this.selectedItemKey];
                this.currentItem = item;
                this.selectedView = 'annotations'; // placeholder for annotation view
                // TODO: navigate to Reader annotation position when reader supports it
                return;
              }
            },
            pendingSyncMap: this.pendingSyncMap,
            pendingSyncRevision: this.pendingSyncRevision,
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
            onItemSaved: () => { this._onItemSaved(); },
            currentItemPendingSync: this.pendingSyncMap[this.currentItem.key ?? ''] === true,
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
          // Auth-in-progress state
          if (this.authLoading) {
            Text('Initializing account…')
              .fontSize(12).fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
          } else {
            // Pending sync count
            if (this.pendingSyncSummaryText.length > 0) {
              Text(this.pendingSyncSummaryText)
                .fontSize(12).fontColor('#E65100')
                .margin({ right: 12 })
            }
            Text(this.syncStatus === 'idle' ? (this.pendingSyncSummaryText.length === 0 ? 'All synced' : 'Ready to sync') :
              (this.syncStatus === 'checking' ? 'Checking libraries' :
                (this.syncStatus === 'syncing' ? 'Syncing library' :
                  (this.syncStatus === 'downloading' ? 'Downloading changes' :
                    (this.syncStatus === 'uploading' ? 'Uploading local changes' :
                      (this.syncStatus === 'success' ? 'Sync complete' :
                        (this.syncStatus === 'offline' ? 'Offline' : 'Sync error')))))))
              .fontSize(12).fontColor(this.themeMode === 'dark' ? '#AAB4C2' : ZHColor.TEXT_MUTED)
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis }).flexShrink(1)
            if (this.syncErrorMessage.length > 0) {
              Text(this.syncErrorMessage)
                .fontSize(11).fontColor('#C62828').maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .margin({ left: 8 })
            }
          }
          Blank()
          Button('Sync').fontSize(12).height(28)
            .enabled(!this.authLoading && this.syncStatus !== 'syncing' && this.syncStatus !== 'checking')
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
            TextInput({ placeholder: 'Collection name', text: this.collectionDialogValue })
              .fontSize(14)
              .height(38)
              .width('100%')
              .onChange((value: string) => { this.collectionDialogValue = value; })
            if (this.collectionDialogError.length > 0) {
              Text(this.collectionDialogError)
                .fontSize(12).fontColor('#C62828').margin({ top: 6 })
            }
            Row() {
              Button('Cancel').fontSize(12).height(32)
                .onClick(() => { this.collectionDialogVisible = false; })
              Blank()
              Button('Create').fontSize(12).height(32)
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

      // ---- New Item dialog ----
      if (this.newItemDialogVisible) {
        Column() {
          Blank().layoutWeight(1)
          Column() {
            Text('New Item').fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
              .margin({ bottom: 10 })
            // Type selector
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(ITEM_TYPE_OPTIONS, (opt: [string, string]) => {
                Button(opt[0])
                  .fontSize(12).height(30)
                  .margin({ right: 4, bottom: 4 })
                  .backgroundColor(this.newItemDialogType === opt[1] ? ZHColor.BRAND : ZHColor.SURFACE_ALT)
                  .fontColor(this.newItemDialogType === opt[1] ? ZHColor.TEXT_INVERSE : ZHColor.TEXT)
                  .onClick(() => { this.newItemDialogType = opt[1]; })
              }, (opt: [string, string]): string => opt[1])
            }
            .width('100%')
            .margin({ bottom: 10 })
            TextInput({ placeholder: 'Title', text: this.newItemDialogTitle })
              .fontSize(14).height(38).width('100%')
              .onChange((value: string) => { this.newItemDialogTitle = value; })
            Row() {
              Button('Cancel').fontSize(12).height(32)
                .onClick(() => { this.newItemDialogVisible = false; })
              Blank()
              Button('Create').fontSize(12).height(32)
                .backgroundColor(ZHColor.BRAND).fontColor(ZHColor.TEXT_INVERSE)
                .onClick(() => { this._createNewItem(); })
            }
            .width('100%').margin({ top: 12 })
          }
          .width('70%').padding(16)
          .backgroundColor(this.themeMode === 'dark' ? '#1B2028' : ZHColor.SURFACE_RAISED)
          .borderRadius(10)
        }
        .width('100%').height('100%').backgroundColor('#80000000')
      }

      // ---- Add by Identifier dialog ----
      if (this.identifierDialogVisible) {
        Column() {
          Blank().layoutWeight(1)
          Column() {
            Text('Add Item by Identifier').fontSize(15).fontWeight(FontWeight.Medium)
              .fontColor(this.themeMode === 'dark' ? '#F4F6FA' : ZHColor.TEXT)
              .margin({ bottom: 8 })
            Text('Enter one identifier per line.')
              .fontSize(12).fontColor(ZHColor.TEXT_MUTED).margin({ bottom: 10 })
            TextArea({ placeholder: 'DOI, ISBN, PMID, or arXiv ID', text: this.identifierDialogText })
              .fontSize(14).height(100).width('100%')
              .onChange((value: string) => { this.identifierDialogText = value; })
            if (this.identifierDialogError.length > 0) {
              Text(this.identifierDialogError)
                .fontSize(12).fontColor('#C62828').margin({ top: 6 })
            }
            Row() {
              Button('Cancel').fontSize(12).height(32)
                .onClick(() => { this.identifierDialogVisible = false; })
              Blank()
              Button('Add').fontSize(12).height(32)
                .backgroundColor(ZHColor.BRAND).fontColor(ZHColor.TEXT_INVERSE)
                .onClick(() => { this._addByIdentifier(); })
            }
            .width('100%').margin({ top: 12 })
          }
          .width('70%').padding(16)
          .backgroundColor(this.themeMode === 'dark' ? '#1B2028' : ZHColor.SURFACE_RAISED)
          .borderRadius(10)
        }
        .width('100%').height('100%').backgroundColor('#80000000')
      }
    }
    .width('100%').height('100%')
    .backgroundColor(this.themeMode === 'dark' ? '#11151B' : ZHColor.SURFACE)
  }

  private _onItemSaved(): void {
    this.revision++;
    let itemKey = this.currentItem.key ?? '';
    if (itemKey.length > 0) {
      let repo = new LibraryRepository();
      repo.open(getContext(this).getApplicationContext()).then(() => {
        return repo.getItemByKey(itemKey);
      }).then((refreshed: ItemModel | null) => {
        if (refreshed) { this.currentItem = refreshed; }
        repo.close();
      }).catch((_err: Error) => { repo.close(); });
    }
    this._refreshPendingSyncState();
  }

  /** Select and display an item by key (details view, phone view). */
  private async _selectItemByKey(itemKey: string): Promise<void> {
    let repo = new LibraryRepository();
    await repo.open(getContext(this).getApplicationContext());
    let item = await repo.getItemByKey(itemKey);
    await repo.close();
    if (item) {
      this.selectedItemKey = itemKey;
      this.selectedItemKeys = [itemKey];
      this.currentItem = item;
      this.selectedView = 'details';
      this.phoneView = PhoneView.DETAIL;
    }
  }

  /** Create a new item from the New Item dialog. */
  private _createNewItem(): void {
    let title = this.newItemDialogTitle.trim();
    if (title.length === 0) { title = '(untitled)'; }
    let itemType = this.newItemDialogType;
    // Determine collection key
    let collectionKey: string | null = null;
    if (this.selectedViewMode === 'collection' && this.selectedCollectionKey.length > 0) {
      collectionKey = this.selectedCollectionKey;
    }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.createItem(collectionKey, itemType, title);
    }).then((newKey: string) => {
      this.newItemDialogVisible = false;
      this.newItemDialogTitle = '';
      this.newItemDialogType = 'journalArticle';
      this.revision++;
      this._refreshPendingSyncState();
      this._selectItemByKey(newKey);
      repo.close();
    }).catch((_err: Error) => { repo.close(); });
  }

  /** Parse identifier lines and create stub items. */
  private _addByIdentifier(): void {
    let lines = this.identifierDialogText.split('\n');
    let entries: IdentifierCreateEntry[] = [];
    for (let i = 0; i < lines.length; i++) {
      let line = lines[i].trim();
      if (line.length === 0) { continue; }
      let idType = IdentifierLookup.classify(line);
      if (idType === 'unknown') { continue; }
      let entry = new IdentifierCreateEntry();
      entry.idType = idType;
      entry.value = line;
      entry.itemType = 'journalArticle';
      if (idType === 'doi') { entry.itemType = 'journalArticle'; entry.fieldName = 'DOI'; entry.title = 'DOI ' + line; }
      else if (idType === 'isbn') { entry.itemType = 'book'; entry.fieldName = 'ISBN'; entry.title = 'ISBN ' + line; }
      else if (idType === 'pmid') { entry.itemType = 'journalArticle'; entry.fieldName = 'extra'; entry.title = 'PMID ' + line; }
      else if (idType === 'arxiv') { entry.itemType = 'report'; entry.fieldName = 'extra'; entry.title = 'arXiv ' + line; }
      entries.push(entry);
    }
    if (entries.length === 0) {
      this.identifierDialogError = 'No valid identifiers found';
      return;
    }
    let collectionKey: string | null = null;
    if (this.selectedViewMode === 'collection' && this.selectedCollectionKey.length > 0) {
      collectionKey = this.selectedCollectionKey;
    }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      let createdKeys: string[] = [];
      let next = Promise.resolve();
      for (let i = 0; i < entries.length; i++) {
        let e = entries[i];
        next = next.then(() => {
          return repo.createItem(collectionKey, e.itemType, e.title);
        }).then((newKey: string) => {
          createdKeys.push(newKey);
          if (e.fieldName === 'extra') {
            return repo.updateItemField(newKey, e.fieldName, `${e.idType.toUpperCase()}: ${e.value}`);
          }
          return repo.updateItemField(newKey, e.fieldName, e.value);
        });
      }
      return next.then(() => {
        this.identifierDialogVisible = false;
        this.identifierDialogText = '';
        this.identifierDialogError = '';
        this.revision++;
        this._refreshPendingSyncState();
        if (createdKeys.length > 0) {
          this._selectItemByKey(createdKeys[0]);
        }
        repo.close();
      });
    }).catch((_err: Error) => { repo.close(); });
  }

  private _doSync(): void {
    if (this.authLoading) {
      this.syncStatus = 'checking';
      this.syncErrorMessage = 'Initializing Zotero account…';
      return;
    }

    if (!this.loggedIn || !AppStore.currentApiKey) {
      this.syncStatus = 'error';
      this.syncErrorMessage = 'Not connected — please connect your Zotero account';
      AppStore.syncStatus = 'error';
      return;
    }

    if (!this.authReady || !this.syncRunner) {
      this._initSyncRunner(AppStore.currentApiKey).then(() => {
        this._doSync();
      }).catch((err: Error) => {
        this.syncStatus = 'error';
        this.syncErrorMessage = err.message || 'Failed to initialize Zotero auth';
      });
      return;
    }

    this.syncStatus = 'checking';
    this.syncErrorMessage = '';
    AppStore.syncStatus = 'checking';
    this.syncRunner.sync(false).then((ok: boolean) => {
        this.syncStatus = ok ? 'success' : 'error';
        AppStore.syncStatus = this.syncStatus;
        if (!ok && this.syncRunner) {
          let errors = this.syncRunner.syncStatus.errors;
          let msg = this.syncRunner.syncStatus.message;
          this.syncErrorMessage = errors.length > 0 ? errors[0] : (msg.length > 0 ? msg : 'Sync failed');
          AppStore.lastSyncTime = this.syncRunner.syncStatus.lastSyncTimestamp;
        }
        this.revision++;
        this._refreshPendingSyncState();
      }).catch((err: Error) => {
        this.syncStatus = 'error';
        this.syncErrorMessage = err.message || 'Sync failed';
        AppStore.syncStatus = 'error';
        this.revision++;
        this._refreshPendingSyncState();
      });
  }

  private _refreshPendingSyncState(): void {
    let repo = new LibraryRepository();
    let context = getContext(this).getApplicationContext();
    repo.open(context).then(() => {
      return repo.getPendingSyncSummary();
    }).then((summary: PendingSyncSummary) => {
      this.pendingSyncSummaryText = formatPendingSyncSummary(summary);
      return repo.getPendingSyncKeySet();
    }).then((map: Record<string, boolean>) => {
      this.pendingSyncMap = map;
      this.pendingSyncRevision++;
      repo.close();
    }).catch((_err: Error) => {
      repo.close();
    });
  }

  private _executeCommand(commandID: string): void {
    zoteroCommandRegistry.execute(commandID, this._commandContext()).then(() => {
      if (commandID === ZoteroCommands.DELETE || commandID === ZoteroCommands.RESTORE || commandID === ZoteroCommands.DUPLICATE_MERGE) {
        this.selectedItemKey = '';
        this.selectedItemKeys = [];
        this.currentItem = new ItemModel();
      }
      this._refreshPendingSyncState();
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
        this._refreshPendingSyncState();
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
      this.collectionDialogError = 'Collection name is required';
      return;
    }
    this.collectionDialogError = '';
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
      this._refreshPendingSyncState();
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
