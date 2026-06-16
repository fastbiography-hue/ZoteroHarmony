/*
 * Central command registry modelled after Zotero Desktop's commandset.
 */

import { router } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import { ZoteroCommand, ZoteroCommandContext, ZoteroCommands } from './ZoteroCommands.ets';
import { LibraryRepository } from '../database/LibraryRepository.ets';
import { CitationService } from '../citation/CitationService.ets';
import { QuickCopy } from '../clipboard/QuickCopy.ets';
import { ItemModel } from '../model/ItemModel.ets';
import { readerManager } from '../reader/ReaderManager.ets';
import { IdentifierLookup } from '../import/IdentifierLookup.ets';
import { Preferences, PrefKey } from '../utils/Preferences.ets';
import { AppStore } from '../utils/AppStore.ets';
import { SyncRunner } from '../sync/SyncRunner.ets';
import { fileIo } from '@kit.CoreFileKit';

export class ZoteroCommandRegistry {
  private commands: Map<string, ZoteroCommand> = new Map();

  constructor() {
    this.registerDefaults();
  }

  getCommand(id: string): ZoteroCommand | null {
    return this.commands.get(id) ?? null;
  }

  canExecute(id: string, context: ZoteroCommandContext): boolean {
    let command = this.getCommand(id);
    if (!command) {
      return false;
    }
    return command.enabled(context);
  }

  async execute(id: string, context: ZoteroCommandContext): Promise<void> {
    let command = this.getCommand(id);
    if (!command || !command.enabled(context)) {
      return;
    }
    await command.execute(context);
  }

  listCommands(): ZoteroCommand[] {
    let result: ZoteroCommand[] = [];
    this.commands.forEach((command: ZoteroCommand) => {
      result.push(command);
    });
    return result;
  }

  private register(command: ZoteroCommand): void {
    this.commands.set(command.id, command);
  }

  private registerDefaults(): void {
    this.register({
      id: ZoteroCommands.NEW_COLLECTION,
      title: 'New Collection',
      shortcut: 'Ctrl+Shift+N',
      enabled: (_context: ZoteroCommandContext): boolean => true,
      execute: async (context: ZoteroCommandContext): Promise<void> => {
        let repo = new LibraryRepository();
        await repo.open(context.appContext);
        await repo.createCollection('New Collection', context.collectionKey.length > 0 ? context.collectionKey : null);
        await repo.close();
        if (context.onLibraryChanged) { context.onLibraryChanged(); }
      },
    });
    this.register({
      id: ZoteroCommands.NEW_ITEM,
      title: 'New Item',
      shortcut: 'Ctrl+N',
      enabled: (_context: ZoteroCommandContext): boolean => true,
      execute: async (context: ZoteroCommandContext): Promise<void> => {
        let repo = new LibraryRepository();
        await repo.open(context.appContext);
        await repo.createItem(context.collectionKey.length > 0 ? context.collectionKey : null, 'journalArticle', 'Untitled Item');
        await repo.close();
        if (context.onLibraryChanged) { context.onLibraryChanged(); }
      },
    });
    this.register({
      id: ZoteroCommands.NEW_NOTE,
      title: 'New Note',
      shortcut: '',
      enabled: (context: ZoteroCommandContext): boolean => context.hasSelection && context.viewMode !== 'trash',
      execute: async (context: ZoteroCommandContext): Promise<void> => {
        let repo = new LibraryRepository();
        await repo.open(context.appContext);
        let parentKey = context.itemKeys.length > 0 ? context.itemKeys[0] : context.itemKey;
        let title = (await repo.getItemByKey(parentKey))?.itemData.get('title') ?? 'New Note';
        let noteKey = await repo.createNote(parentKey, `${title} Note`, '');
        await repo.close();
        if (noteKey.length > 0) {
          if (context.onItemCreated) {
            context.onItemCreated(noteKey, 'note', 'Note added');
          } else if (context.onLibraryChanged) {
            context.onLibraryChanged();
          }
        } else if (context.onWorkflowMessage) {
          context.onWorkflowMessage('Failed to add note');
        }
      },
    });
    this.register({
      id: ZoteroCommands.ADD_ATTACHMENT,
      title: 'Add Attachment',
      shortcut: '',
      enabled: (context: ZoteroCommandContext): boolean => context.hasSelection,
      execute: async (context: ZoteroCommandContext): Promise<void> => {
        let url = '';
        try { url = (await QuickCopy.readText()).trim(); } catch (_err) { url = ''; }
        let attachmentKey = '';
        let repo = new LibraryRepository();
        await repo.open(context.appContext);
        try {
          if (url.length > 0 && (url.startsWith('http://') || url.startsWith('https://'))) {
            attachmentKey = await repo.createLinkedUrlAttachment(context.itemKey, url);
          } else {
            let isFile = false;
            try { isFile = url.length > 0 && fileIo.accessSync(url); } catch (_e) { isFile = false; }
            if (isFile) {
              attachmentKey = await repo.createImportedFileAttachment(context.itemKey, url, context.appContext);
            } else {
              let documentSelectOptions = new picker.DocumentSelectOptions();
              documentSelectOptions.maxSelectNumber = 1;
              let documentViewPicker = new picker.DocumentViewPicker(context.appContext);
              let uris = await documentViewPicker.select(documentSelectOptions);
              if (uris.length > 0) {
                attachmentKey = await repo.createImportedFileAttachment(context.itemKey, uris[0], context.appContext);
              }
            }
          }
        } finally {
          await repo.close();
        }
        if (attachmentKey.length > 0) {
          if (context.onItemCreated) {
            context.onItemCreated(attachmentKey, 'details', 'Attachment added');
          } else if (context.onLibraryChanged) {
            context.onLibraryChanged();
          }
        } else if (context.onWorkflowMessage) {
          context.onWorkflowMessage('No attachment added');
        }
      },
    });
    this.register({
      id: ZoteroCommands.REMOVE_FROM_COLLECTION,
      title: 'Remove from Collection',
      shortcut: '',
      enabled: (context: ZoteroCommandContext): boolean =>
        context.hasSelection && context.viewMode === 'collection' && context.collectionKey.length > 0,
      execute: async (context: ZoteroCommandContext): Promise<void> => {
        let keys = context.itemKeys.length > 0 ? context.itemKeys : [context.itemKey];
        if (keys.length === 0) { return; }
        let repo = new LibraryRepository();
        await repo.open(context.appContext);
        await repo.removeItemsFromCollection(keys, context.collectionKey);
        await repo.close();
        if (context.onLibraryChanged) { context.onLibraryChanged(); }
        if (context.onWorkflowMessage) {
          context.onWorkflowMessage('Removed from collection');
        }
      },
    });
    this.register({
      id: ZoteroCommands.ADD_TO_COLLECTION,
      title: 'Add to Collection',
      shortcut: '',
      enabled: (context: ZoteroCommandContext): boolean => context.hasSelection && context.viewMode !== 'trash',
      execute: async (context: ZoteroCommandContext): Promise<void> => {
        router.pushUrl({
          url: 'pages/AddToCollectionPage',
          params: {
            itemKeys: context.itemKeys.join(','),
            collectionKey: context.collectionKey,
          },
        });
      },
    });
    this.register({
      id: ZoteroCommands.ADD_BY_IDENTIFIER,
      title: 'Add by Identifier',
      shortcut: 'Ctrl+Shift+I',
      enabled: (_context: ZoteroCommandContext): boolean => true,
      execute: async (context: ZoteroCommandContext): Promise<void> => {
        let identifier = (await QuickCopy.readText()).trim();
        let type = IdentifierLookup.classify(identifier);
        if (type !== 'doi' && type !== 'isbn' && type !== 'arxiv' && type !== 'pmid') {
          return;
        }
        let itemType = type === 'isbn' ? 'book' : (type === 'arxiv' ? 'report' : 'journalArticle');
        let title = `${type.toUpperCase()} ${type === 'isbn' ? IdentifierLookup.cleanISBN(identifier) : identifier}`;
        let repo = new LibraryRepository();
        await repo.open(context.appContext);
        let key = await repo.createItem(context.collectionKey.length > 0 ? context.collectionKey : null, itemType, title);
        if (type === 'doi') {
          await repo.updateItemField(key, 'DOI', identifier);
        } else if (type === 'isbn') {
          await repo.updateItemField(key, 'ISBN', IdentifierLookup.cleanISBN(identifier));
        } else {
          await repo.updateItemField(key, 'extra', `${type}: ${identifier}`);
        }
        await repo.close();
        if (context.onLibraryChanged) { context.onLibraryChanged(); }
      },
    });
    this.register({
      id: ZoteroCommands.IMPORT,
      title: 'Import',
      shortcut: 'Ctrl+Shift+O',
      enabled: (_context: ZoteroCommandContext): boolean => true,
      execute: async (context: ZoteroCommandContext): Promise<void> => {
        router.pushUrl({ url: 'pages/ImportExportPage', params: { mode: 'import', collectionKey: context.collectionKey } });
      },
    });
    this.register({
      id: ZoteroCommands.EXPORT,
      title: 'Export',
      shortcut: '',
      enabled: (context: ZoteroCommandContext): boolean => context.hasSelection || context.collectionKey.length > 0,
      execute: async (context: ZoteroCommandContext): Promise<void> => {
        router.pushUrl({
          url: 'pages/ImportExportPage',
          params: { mode: 'export', itemKeys: context.itemKeys.join(','), collectionKey: context.collectionKey },
        });
      },
    });
    this.register({
      id: ZoteroCommands.COPY_CITATION,
      title: 'Copy Citation',
      shortcut: 'Ctrl+Shift+C',
      enabled: (context: ZoteroCommandContext): boolean => context.hasSelection,
      execute: async (context: ZoteroCommandContext): Promise<void> => {
        await Preferences.init(context.appContext);
        let quickCopyStyle = (await Preferences.getString(PrefKey.QUICK_COPY_STYLE)).toLowerCase();
        let styleName = quickCopyStyle.includes('vancouver') || quickCopyStyle.includes('ieee') || quickCopyStyle.includes('numeric') ? 'numeric' : quickCopyStyle;
        let items = await this.getSelectedItems(context);
        if (items.length > 0) {
          let citations: string[] = [];
          for (let i = 0; i < items.length; i++) {
            citations.push(CitationService.generateCitation(items[i], 'text', 'en-US', styleName));
          }
          await QuickCopy.copyText(citations.join('\n'));
        }
      },
    });
    this.register({
      id: ZoteroCommands.COPY_BIBLIOGRAPHY,
      title: 'Copy Bibliography',
      shortcut: 'Ctrl+Shift+B',
      enabled: (context: ZoteroCommandContext): boolean => context.hasSelection,
      execute: async (context: ZoteroCommandContext): Promise<void> => {
        await Preferences.init(context.appContext);
        let quickCopyStyle = (await Preferences.getString(PrefKey.QUICK_COPY_STYLE)).toLowerCase();
        let styleName = quickCopyStyle.includes('vancouver') || quickCopyStyle.includes('ieee') || quickCopyStyle.includes('numeric') ? 'numeric' : quickCopyStyle;
        let items = await this.getSelectedItems(context);
        if (items.length > 0) {
          await QuickCopy.copyText(CitationService.generateBibliography(items, styleName, 'text'));
        }
      },
    });
    this.register({
      id: ZoteroCommands.SYNC,
      title: 'Sync',
      shortcut: '',
      enabled: (_context: ZoteroCommandContext): boolean => true,
      execute: async (context: ZoteroCommandContext): Promise<void> => {
        await Preferences.init(context.appContext);
        let apiKey = AppStore.currentApiKey;
        if (apiKey.length === 0) {
          apiKey = await Preferences.getString(PrefKey.API_KEY);
        }
        if (apiKey.length === 0) {
          AppStore.syncStatus = 'error';
          return;
        }
        let apiUrl = await Preferences.getString(PrefKey.API_URL);
        let runner = new SyncRunner(apiUrl, context.appContext);
        await runner.loginWithApiKey(apiKey);
        AppStore.syncStatus = 'checking';
        let ok = await runner.sync(false);
        AppStore.syncStatus = ok ? 'success' : 'error';
        AppStore.lastSyncTime = runner.syncStatus.lastSyncTimestamp;
        if (context.onLibraryChanged) {
          context.onLibraryChanged();
        }
      },
    });
    this.register({
      id: ZoteroCommands.DELETE,
      title: 'Delete',
      shortcut: 'Delete',
      enabled: (context: ZoteroCommandContext): boolean => context.hasSelection,
      execute: async (context: ZoteroCommandContext): Promise<void> => {
        let repo = new LibraryRepository();
        await repo.open(context.appContext);
        await repo.moveItemsToTrash(context.itemKeys.length > 0 ? context.itemKeys : [context.itemKey]);
        await repo.close();
        if (context.onLibraryChanged) { context.onLibraryChanged(); }
      },
    });
    this.register({
      id: ZoteroCommands.DUPLICATE_MERGE,
      title: 'Merge Duplicates',
      shortcut: '',
      enabled: (context: ZoteroCommandContext): boolean => context.viewMode === 'duplicates' && context.itemKeys.length > 1,
      execute: async (context: ZoteroCommandContext): Promise<void> => {
        let repo = new LibraryRepository();
        await repo.open(context.appContext);
        let survivorKey = await repo.mergeItems(context.itemKeys);
        await repo.close();
        if (survivorKey && context.onLibraryChanged) {
          context.onLibraryChanged();
        }
      },
    });
    this.register({
      id: ZoteroCommands.RESTORE,
      title: 'Restore from Trash',
      shortcut: '',
      enabled: (context: ZoteroCommandContext): boolean => context.hasSelection && context.viewMode === 'trash',
      execute: async (context: ZoteroCommandContext): Promise<void> => {
        let repo = new LibraryRepository();
        await repo.open(context.appContext);
        await repo.restoreItemsFromTrash(context.itemKeys.length > 0 ? context.itemKeys : [context.itemKey]);
        await repo.close();
        if (context.onLibraryChanged) { context.onLibraryChanged(); }
      },
    });
    this.register({
      id: ZoteroCommands.OPEN_READER,
      title: 'Open Reader',
      shortcut: 'Enter',
      enabled: (context: ZoteroCommandContext): boolean => context.hasSelection,
      execute: async (context: ZoteroCommandContext): Promise<void> => {
        let item = await this.getSelectedItem(context);
        if (!item) {
          return;
        }
        let title = item.itemData.get('title') ?? 'Reader';
        let path = item.attachmentPath ?? item.itemData.get('path') ?? '';
        readerManager.open(item.id ?? 0, context.itemKey, title, path, 1);
        router.pushUrl({ url: 'reader/ReaderPage', params: { itemKey: context.itemKey } });
      },
    });
    this.register({
      id: ZoteroCommands.SHOW_PREFERENCES,
      title: 'Preferences',
      shortcut: '',
      enabled: (_context: ZoteroCommandContext): boolean => true,
      execute: async (_context: ZoteroCommandContext): Promise<void> => {
        router.pushUrl({ url: 'pages/PreferencesPage' });
      },
    });
  }

  private async getSelectedItem(context: ZoteroCommandContext): Promise<ItemModel | null> {
    let repo = new LibraryRepository();
    await repo.open(context.appContext);
    let item = await repo.getItemByKey(context.itemKey);
    await repo.close();
    return item;
  }

  private async getSelectedItems(context: ZoteroCommandContext): Promise<ItemModel[]> {
    let keys = context.itemKeys.length > 0 ? context.itemKeys : [context.itemKey];
    let repo = new LibraryRepository();
    await repo.open(context.appContext);
    let items = await repo.getItemsByKeys(keys);
    await repo.close();
    return items;
  }
}

export const zoteroCommandRegistry = new ZoteroCommandRegistry();
