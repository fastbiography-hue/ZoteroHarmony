/*
 * Zotero command identifiers shared by toolbars, menus, shortcuts, and context menus.
 */

export class ZoteroCommands {
  static readonly NEW_COLLECTION: string = 'zotero.newCollection';
  static readonly NEW_ITEM: string = 'zotero.newItem';
  static readonly NEW_NOTE: string = 'zotero.newNote';
  static readonly ADD_ATTACHMENT: string = 'zotero.addAttachment';
  static readonly ADD_TO_COLLECTION: string = 'zotero.addToCollection';
  static readonly ADD_BY_IDENTIFIER: string = 'zotero.addByIdentifier';
  static readonly IMPORT: string = 'zotero.import';
  static readonly EXPORT: string = 'zotero.export';
  static readonly COPY_CITATION: string = 'zotero.copyCitation';
  static readonly COPY_BIBLIOGRAPHY: string = 'zotero.copyBibliography';
  static readonly SYNC: string = 'zotero.sync';
  static readonly DELETE: string = 'zotero.delete';
  static readonly RESTORE: string = 'zotero.restore';
  static readonly DUPLICATE_MERGE: string = 'zotero.duplicateMerge';
  static readonly REMOVE_FROM_COLLECTION: string = 'zotero.removeFromCollection';
  static readonly OPEN_READER: string = 'zotero.openReader';
  static readonly SHOW_PREFERENCES: string = 'zotero.showPreferences';
}

export interface ZoteroCommandContext {
  appContext: Context;
  libraryID: number;
  collectionKey: string;
  itemKey: string;
  itemKeys: string[];
  viewMode: string;
  hasSelection: boolean;
  onLibraryChanged?: () => void;
  /** Notify that a child item (note/attachment) was created. */
  onItemCreated?: (itemKey: string, viewHint: string, message: string) => void;
  /** Display a transient message in the footer. */
  onWorkflowMessage?: (message: string) => void;
}

export type ZoteroCommandHandler = (context: ZoteroCommandContext) => Promise<void>;

export interface ZoteroCommand {
  id: string;
  title: string;
  shortcut: string;
  enabled: (context: ZoteroCommandContext) => boolean;
  execute: ZoteroCommandHandler;
}
