/*
 * Local-library repository for UI view models.
 *
 * Keeps ArkUI components DB-backed while preserving Zotero-like tables.
 */

import { ZoteroDb, Row } from './ZoteroDb.ets';
import { migrate } from './SchemaMigration.ets';
import { ItemModel } from '../model/ItemModel.ets';
import { AttachmentLinkMode, ZoteroTag } from '../model/ItemTypes.ets';
import { CollectionTreeRow } from '../ui/tree/CollectionTreeRow.ets';
import { AttachmentEntry } from '../ui/AttachmentsList.ets';
import { StorageRequest } from '../sync/StorageRequest.ets';
import { PdfAnnotation } from '../reader/ReaderTypes.ets';
import { NoteEntry } from '../ui/NotesList.ets';
import { JoinMode, SearchCondition } from '../search/SearchEngine.ets';
import { FileStorage } from '../utils/FileStorage.ets';
import { RelatedItemRef } from '../model/RelatedItemModel.ets';

export interface SavedSearchConditionData {
  condition: string;
  operator: string;
  value: string;
  required: boolean;
}

export interface SavedSearchQueryData {
  key: string;
  name: string;
  joinMode: JoinMode;
  conditions: SearchCondition[];
}

export type RemoteObjectType = 'collection' | 'item' | 'search';

/** Lightweight child-row summary for item-tree hierarchy. */
export interface ItemChildSummary {
  key: string;
  parentKey: string;
  childType: 'attachment' | 'note' | 'annotation';
  title: string;
  subtitle: string;
  sortIndex: string;
}

export class LibraryRepository {
  private db: ZoteroDb;

  constructor() {
    this.db = new ZoteroDb('zotero.sqlite');
  }

  async open(context: Context): Promise<void> {
    await this.db.open(context);
    await migrate(this.db);
    await this.ensureStarterData();
  }

  async close(): Promise<void> {
    await this.db.close();
  }

  async listCollectionRows(): Promise<CollectionTreeRow[]> {
    let rows: CollectionTreeRow[] = [
      {
        id: 'L1',
        type: 'library',
        name: 'My Library',
        level: 0,
        isOpen: true,
        hasChildren: true,
        libraryID: 1,
      },
    ];

    let collections = await this.db.queryAsync(
      `SELECT collectionID, collectionName, parentCollectionID, libraryID, key
       FROM collections
       WHERE libraryID = 1
       ORDER BY parentCollectionID IS NOT NULL, parentCollectionID, collectionName`
    );
    this.appendCollectionChildren(rows, collections, null, 1);

    let searches = await this.db.queryAsync(
      `SELECT savedSearchID, savedSearchName, libraryID, key
       FROM savedSearches
       WHERE libraryID = 1
       ORDER BY savedSearchName`
    );
    for (let i = 0; i < searches.length; i++) {
      let searchID = this.toNumber(searches[i]['savedSearchID']);
      rows.push({
        id: `S${searchID}`,
        type: 'search',
        name: this.toString(searches[i]['savedSearchName'], 'Saved Search'),
        level: 1,
        isOpen: false,
        hasChildren: false,
        libraryID: this.toNumber(searches[i]['libraryID']),
        key: this.toString(searches[i]['key'], ''),
        parentRowID: 'L1',
      });
    }

    rows.push({ id: 'duplicates-1', type: 'duplicates', name: 'Duplicate Items', level: 1, isOpen: false, hasChildren: false, libraryID: 1, parentRowID: 'L1' });
    rows.push({ id: 'unfiled-1', type: 'unfiled', name: 'Unfiled Items', level: 1, isOpen: false, hasChildren: false, libraryID: 1, parentRowID: 'L1' });
    rows.push({ id: 'trash-1', type: 'trash', name: 'Trash', level: 1, isOpen: false, hasChildren: false, libraryID: 1, parentRowID: 'L1' });
    return rows;
  }

  async listItems(collectionKey: string | null, filterText: string): Promise<ItemModel[]> {
    let params: (string | number | null)[] = [];
    let where = `WHERE i.libraryID = 1
       AND NOT EXISTS (SELECT 1 FROM deletedItems di WHERE di.itemID = i.itemID)`;
    if (collectionKey !== null && collectionKey.length > 0) {
      where += ` AND c.key = ?`;
      params.push(collectionKey);
    }
    return this.queryItems(where, params, filterText);
  }

  async listUnfiledItems(filterText: string): Promise<ItemModel[]> {
    return this.queryItems(
      `WHERE i.libraryID = 1
       AND NOT EXISTS (SELECT 1 FROM deletedItems di WHERE di.itemID = i.itemID)
       AND NOT EXISTS (SELECT 1 FROM collectionItems ci2 WHERE ci2.itemID = i.itemID)`,
      [],
      filterText
    );
  }

  async listTrashItems(filterText: string): Promise<ItemModel[]> {
    return this.queryItems(
      `WHERE i.libraryID = 1
       AND EXISTS (SELECT 1 FROM deletedItems di WHERE di.itemID = i.itemID)`,
      [],
      filterText
    );
  }

  async listDuplicateItems(filterText: string): Promise<ItemModel[]> {
    let items = await this.listItems(null, filterText);
    let seen: Map<string, number> = new Map();
    let duplicateKeys: string[] = [];
    for (let i = 0; i < items.length; i++) {
      let title = (items[i].itemData.get('title') ?? '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
      let year = (items[i].itemData.get('date') ?? '').replace(/[^0-9]+/g, '').substring(0, 4);
      let key = `${title}|${year}`;
      if (title.length === 0) {
        continue;
      }
      let count = seen.get(key) ?? 0;
      seen.set(key, count + 1);
      if (count === 1) {
        duplicateKeys.push(key);
      }
    }
    if (duplicateKeys.length === 0) {
      return [];
    }
    return items.filter((item: ItemModel): boolean => {
      let title = (item.itemData.get('title') ?? '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
      let year = (item.itemData.get('date') ?? '').replace(/[^0-9]+/g, '').substring(0, 4);
      return duplicateKeys.indexOf(`${title}|${year}`) >= 0;
    });
  }

  private async queryItems(where: string, params: (string | number | null)[], filterText: string): Promise<ItemModel[]> {

    let rows = await this.db.queryAsync(
      `SELECT i.itemID, i.libraryID, i.key, i.itemTypeID, i.version, i.dateAdded,
              i.dateModified, it.typeName, f.fieldName, v.value,
              cr.firstName, cr.lastName
       FROM items i
       LEFT JOIN itemTypes it ON it.itemTypeID = i.itemTypeID
       LEFT JOIN itemData d ON d.itemID = i.itemID
       LEFT JOIN fields f ON f.fieldID = d.fieldID
       LEFT JOIN itemDataValues v ON v.valueID = d.valueID
       LEFT JOIN itemCreators ic ON ic.itemID = i.itemID AND ic.orderIndex = 0
       LEFT JOIN creators cr ON cr.creatorID = ic.creatorID
       LEFT JOIN itemAttachments ia ON ia.itemID = i.itemID
       LEFT JOIN itemNotes n ON n.itemID = i.itemID
       LEFT JOIN collectionItems ci ON ci.itemID = i.itemID
       LEFT JOIN collections c ON c.collectionID = ci.collectionID
       ${where}
       ORDER BY i.dateModified DESC, i.itemID DESC`,
      params
    );

    let itemIDs: number[] = [];
    let items: ItemModel[] = [];
    for (let i = 0; i < rows.length; i++) {
      let itemID = this.toNumber(rows[i]['itemID']);
      let existingIndex = itemIDs.indexOf(itemID);
      let item: ItemModel;
      if (existingIndex >= 0) {
        item = items[existingIndex];
      } else {
        item = new ItemModel();
        item.id = itemID;
        item.libraryID = this.toNumber(rows[i]['libraryID']);
        item.key = this.toString(rows[i]['key'], '');
        item.version = this.toNumber(rows[i]['version']);
        item.dateAdded = this.toString(rows[i]['dateAdded'], '');
        item.dateModified = this.toString(rows[i]['dateModified'], '');
        item.itemTypeID = this.toNumber(rows[i]['itemTypeID']);
        item.itemData.set('itemType', this.toString(rows[i]['typeName'], 'journalArticle'));
        let creator = this.creatorName(rows[i]);
        if (creator.length > 0) {
          item.itemData.set('creator', creator);
        }
        let typeName = this.toString(rows[i]['typeName'], 'journalArticle');
        if (typeName === 'attachment') {
          item.attachmentLinkMode = this.toNumber(rows[i]['linkMode']) as AttachmentLinkMode;
          item.attachmentPath = this.toString(rows[i]['path'], '');
          item.attachmentContentType = this.toString(rows[i]['contentType'], '');
        } else if (typeName === 'note') {
          let noteText = this.toString(rows[i]['note'], '');
          item.noteText = noteText;
          item.displayTitle = this.toString(rows[i]['title'], '') || noteText.substring(0, 80);
        }
        itemIDs.push(itemID);
        items.push(item);
      }
      let fieldName = this.toString(rows[i]['fieldName'], '');
      if (fieldName.length > 0) {
        item.itemData.set(fieldName, this.toString(rows[i]['value'], ''));
      }
    }

    if (filterText.length === 0) {
      await this.attachTags(items);
      return items;
    }
    await this.attachTags(items);
    let needle = filterText.toLowerCase();
    return items.filter((item: ItemModel): boolean => {
      return (item.itemData.get('title') ?? '').toLowerCase().includes(needle) ||
        (item.itemData.get('creator') ?? '').toLowerCase().includes(needle) ||
        (item.itemData.get('date') ?? '').toLowerCase().includes(needle) ||
        (item.itemData.get('publisher') ?? '').toLowerCase().includes(needle) ||
        (item.itemData.get('publicationTitle') ?? '').toLowerCase().includes(needle);
    });
  }

  async getItemByKey(itemKey: string): Promise<ItemModel | null> {
    if (itemKey.length === 0) {
      return null;
    }
    let items = await this.listItems(null, '');
    for (let i = 0; i < items.length; i++) {
      if ((items[i].key ?? '') === itemKey) {
        return items[i];
      }
    }
    return null;
  }

  async getItemsByKeys(itemKeys: string[]): Promise<ItemModel[]> {
    if (itemKeys.length === 0) {
      return [];
    }
    let allItems = await this.listItems(null, '');
    let result: ItemModel[] = [];
    for (let i = 0; i < allItems.length; i++) {
      let key = allItems[i].key ?? '';
      if (itemKeys.indexOf(key) >= 0) {
        result.push(allItems[i]);
      }
    }
    return result;
  }

  async listAttachments(itemKey: string): Promise<AttachmentEntry[]> {
    let parentID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [itemKey]
    ));
    if (parentID === 0) {
      return [];
    }
    let rows = await this.db.queryAsync(
      `SELECT i.itemID, i.key, ia.contentType, ia.linkMode, ia.path, ia.syncState, v.value AS title
       FROM itemAttachments ia
       JOIN items i ON i.itemID = ia.itemID
       LEFT JOIN itemData d ON d.itemID = i.itemID AND d.fieldID = 1
       LEFT JOIN itemDataValues v ON v.valueID = d.valueID
       WHERE ia.parentItemID = ?
       ORDER BY i.dateAdded`,
      [parentID]
    );
    let attachments: AttachmentEntry[] = [];
    for (let i = 0; i < rows.length; i++) {
      attachments.push({
        id: this.toNumber(rows[i]['itemID']),
        key: this.toString(rows[i]['key'], ''),
        filename: this.toString(rows[i]['title'], this.toString(rows[i]['path'], 'Attachment')),
        contentType: this.toString(rows[i]['contentType'], 'text/html'),
        linkMode: this.linkModeName(this.toNumber(rows[i]['linkMode'])),
        path: this.toString(rows[i]['path'], ''),
        syncState: this.toNumber(rows[i]['syncState']),
      });
    }
    return attachments;
  }

  async listAnnotations(itemKey: string): Promise<PdfAnnotation[]> {
    let itemID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [itemKey]
    ));
    if (itemID === 0) {
      return [];
    }
    let rows = await this.db.queryAsync(
      `SELECT annotationID, type, pageIndex, x, y, width, height, color,
              text, comment, authorName, sortIndex, dateModified
       FROM itemAnnotations
       WHERE parentItemID = ?
       ORDER BY pageIndex, sortIndex, dateModified`,
      [itemID]
    );
    let annotations: PdfAnnotation[] = [];
    for (let i = 0; i < rows.length; i++) {
      annotations.push({
        id: this.toString(rows[i]['annotationID'], ''),
        type: this.toAnnotationType(this.toString(rows[i]['type'], 'highlight')),
        pageIndex: this.toNumber(rows[i]['pageIndex']),
        position: {
          x: this.toFloat(rows[i]['x']),
          y: this.toFloat(rows[i]['y']),
          width: this.toFloat(rows[i]['width']),
          height: this.toFloat(rows[i]['height']),
        },
        color: this.toString(rows[i]['color'], '#FFD700'),
        text: this.toString(rows[i]['text'], ''),
        comment: this.toString(rows[i]['comment'], ''),
        authorName: this.toString(rows[i]['authorName'], ''),
        sortIndex: this.toString(rows[i]['sortIndex'], ''),
        dateModified: this.toString(rows[i]['dateModified'], ''),
      });
    }
    return annotations;
  }

  async saveAnnotation(itemKey: string, annotation: PdfAnnotation): Promise<void> {
    let itemID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [itemKey]
    ));
    if (itemID === 0 || annotation.id.length === 0) {
      return;
    }
    await this.db.executeSql(
      `INSERT OR REPLACE INTO itemAnnotations
       (annotationID, parentItemID, type, pageIndex, x, y, width, height,
        color, text, comment, authorName, sortIndex, dateModified, synced)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)`,
      [
        annotation.id,
        itemID,
        annotation.type,
        annotation.pageIndex,
        annotation.position.x,
        annotation.position.y,
        annotation.position.width,
        annotation.position.height,
        annotation.color,
        annotation.text ?? '',
        annotation.comment ?? '',
        annotation.authorName ?? '',
        annotation.sortIndex,
        annotation.dateModified,
      ]
    );
    // TODO: when annotations become first-class Zotero items, check
    // if annotation.id maps to an items.key and enqueue that key.
    // For now, enqueue the parent attachment so its metadata stays in sync.
    await this.addToSyncQueue(1, 'item', [itemKey]);
  }

  async deleteAnnotation(itemKey: string, annotationID: string): Promise<void> {
    let itemID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [itemKey]
    ));
    if (itemID === 0 || annotationID.length === 0) {
      return;
    }
    await this.db.executeSql(
      `DELETE FROM itemAnnotations WHERE parentItemID = ? AND annotationID = ?`,
      [itemID, annotationID]
    );
    // TODO: when annotations become first-class items, check
    // if annotationID maps to an items.key and addToDeleteLog for it.
    // For now, enqueue the parent attachment for sync.
    await this.addToSyncQueue(1, 'item', [itemKey]);
  }

  private async ensureStarterData(): Promise<void> {
    await this.db.executeSql(
      `INSERT OR IGNORE INTO libraries (libraryID, type, editable, filesEditable)
       VALUES (1, 'user', 1, 1)`
    );
    let count = await this.db.valueQueryAsync(`SELECT COUNT(*) FROM items WHERE libraryID = 1`);
    if (this.toNumber(count) > 0) {
      return;
    }

    await this.db.executeTransaction(async (): Promise<void> => {
      await this.db.executeSql(
        `INSERT OR IGNORE INTO collections (collectionName, parentCollectionID, libraryID, key, synced)
         VALUES ('Research Papers', NULL, 1, 'research-papers', 1)`
      );
      await this.db.executeSql(
        `INSERT OR IGNORE INTO collections (collectionName, parentCollectionID, libraryID, key, synced)
         VALUES ('Coursework', NULL, 1, 'coursework', 1)`
      );

      let researchID = this.toNumber(await this.db.valueQueryAsync(
        `SELECT collectionID FROM collections WHERE key = 'research-papers'`
      ));
      let courseworkID = this.toNumber(await this.db.valueQueryAsync(
        `SELECT collectionID FROM collections WHERE key = 'coursework'`
      ));

      await this.insertStarterItem('Attention Is All You Need', 'Vaswani et al.', 'conferencePaper', '2017', 'NeurIPS', researchID);
      await this.insertStarterItem('A Survey of Large Language Models', 'Zhao et al.', 'journalArticle', '2024', 'AI Open', researchID);
      await this.insertStarterItem('Understanding Deep Learning', 'Prince', 'book', '2023', 'MIT Press', courseworkID);
      await this.insertStarterItem('Scaling Laws for Neural Language Models', 'Kaplan et al.', 'journalArticle', '2020', 'arXiv', researchID);
    });
  }

  async createCollection(name: string, parentCollectionKey: string | null): Promise<string> {
    let parentID: number | null = null;
    if (parentCollectionKey !== null && parentCollectionKey.length > 0) {
      parentID = this.toNumber(await this.db.valueQueryAsync(
        `SELECT collectionID FROM collections WHERE libraryID = 1 AND key = ?`,
        [parentCollectionKey]
      ));
      if (parentID === 0) {
        parentID = null;
      }
    }
    let key = await this.uniqueKey('collections', name);
    if (parentID === null) {
      await this.db.executeSql(
        `INSERT INTO collections (collectionName, parentCollectionID, libraryID, key, synced)
         VALUES (?, NULL, 1, ?, 0)`,
        [name, key]
      );
    } else {
      await this.db.executeSql(
        `INSERT INTO collections (collectionName, parentCollectionID, libraryID, key, synced)
         VALUES (?, ?, 1, ?, 0)`,
        [name, parentID, key]
      );
    }
    await this.addToSyncQueue(1, 'collection', [key]);
    return key;
  }

  async renameCollection(collectionKey: string, newName: string): Promise<void> {
    if (collectionKey.length === 0 || newName.trim().length === 0) {
      return;
    }
    let collectionID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT collectionID FROM collections WHERE libraryID = 1 AND key = ?`,
      [collectionKey]
    ));
    if (collectionID === 0) {
      return;
    }
    await this.db.executeSql(
      `UPDATE collections SET collectionName = ?, synced = 0 WHERE collectionID = ?`,
      [newName.trim(), collectionID]
    );
    await this.addToSyncQueue(1, 'collection', [collectionKey]);
  }

  async deleteCollection(collectionKey: string): Promise<void> {
    if (collectionKey.length === 0) {
      return;
    }
    let collectionID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT collectionID FROM collections WHERE libraryID = 1 AND key = ?`,
      [collectionKey]
    ));
    if (collectionID === 0) {
      return;
    }
    await this.db.executeTransaction(async (): Promise<void> => {
      await this.db.executeSql(`DELETE FROM collectionItems WHERE collectionID = ?`, [collectionID]);
      await this.db.executeSql(`DELETE FROM collections WHERE collectionID = ?`, [collectionID]);
    });
    // TODO: if collection was created locally and never synced, we could
    // remove from syncQueue instead of adding to deleteLog.
    await this.addToDeleteLog(1, 'collection', [collectionKey]);
  }

  async renameSavedSearch(searchKey: string, newName: string): Promise<void> {
    if (searchKey.length === 0 || newName.trim().length === 0) {
      return;
    }
    let savedSearchID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT savedSearchID FROM savedSearches WHERE libraryID = 1 AND key = ?`,
      [searchKey]
    ));
    if (savedSearchID === 0) {
      return;
    }
    await this.db.executeSql(
      `UPDATE savedSearches SET savedSearchName = ?, clientDateModified = datetime('now'), synced = 0 WHERE savedSearchID = ?`,
      [newName.trim(), savedSearchID]
    );
    await this.addToSyncQueue(1, 'search', [searchKey]);
  }

  async deleteSavedSearch(searchKey: string): Promise<void> {
    if (searchKey.length === 0) {
      return;
    }
    let savedSearchID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT savedSearchID FROM savedSearches WHERE libraryID = 1 AND key = ?`,
      [searchKey]
    ));
    if (savedSearchID === 0) {
      return;
    }
    await this.db.executeTransaction(async (): Promise<void> => {
      await this.db.executeSql(`DELETE FROM savedSearchConditions WHERE savedSearchID = ?`, [savedSearchID]);
      await this.db.executeSql(`DELETE FROM savedSearches WHERE savedSearchID = ?`, [savedSearchID]);
    });
    await this.addToDeleteLog(1, 'search', [searchKey]);
  }

  async createItem(collectionKey: string | null, itemType: string, title: string): Promise<string> {
    let typeID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemTypeID FROM itemTypes WHERE typeName = ?`, [itemType]
    ));
    let key = await this.uniqueKey('items', title);
    await this.db.executeTransaction(async (): Promise<void> => {
      await this.db.executeSql(
        `INSERT INTO items (itemTypeID, libraryID, key, version, synced)
         VALUES (?, 1, ?, 0, 0)`,
        [typeID > 0 ? typeID : 1, key]
      );
      let itemID = this.toNumber(await this.db.valueQueryAsync(
        `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [key]
      ));
      if (collectionKey !== null && collectionKey.length > 0) {
        let collectionID = this.toNumber(await this.db.valueQueryAsync(
          `SELECT collectionID FROM collections WHERE libraryID = 1 AND key = ?`,
          [collectionKey]
        ));
        if (collectionID > 0) {
          await this.db.executeSql(
            `INSERT OR IGNORE INTO collectionItems (collectionID, itemID) VALUES (?, ?)`,
            [collectionID, itemID]
          );
        }
      }
      await this.putItemField(itemID, 'title', title);
      await this.putItemField(itemID, 'itemType', itemType);
      await this.putItemField(itemID, 'date', `${new Date().getFullYear()}`);
    });
    await this.addToSyncQueue(1, 'item', [key]);
    return key;
  }

  async listNotes(itemKey: string): Promise<NoteEntry[]> {
    let parentID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [itemKey]
    ));
    if (parentID === 0) {
      return [];
    }
    let rows = await this.db.queryAsync(
      `SELECT i.itemID, i.key, n.title, n.note, i.dateModified
       FROM itemNotes n
       JOIN items i ON i.itemID = n.itemID
       WHERE n.parentItemID = ?
       AND NOT EXISTS (SELECT 1 FROM deletedItems di WHERE di.itemID = i.itemID)
       ORDER BY i.dateModified DESC`,
      [parentID]
    );
    let notes: NoteEntry[] = [];
    for (let i = 0; i < rows.length; i++) {
      let noteText = this.toString(rows[i]['note'], '');
      notes.push({
        id: this.toNumber(rows[i]['itemID']),
        key: this.toString(rows[i]['key'], ''),
        title: this.toString(rows[i]['title'], 'Note'),
        preview: noteText.substring(0, 120),
        dateModified: this.toString(rows[i]['dateModified'], ''),
        noteText: noteText,
      });
    }
    return notes;
  }

  async createNote(parentItemKey: string, title: string, noteText: string): Promise<string> {
    let parentID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [parentItemKey]
    ));
    if (parentID === 0) {
      return '';
    }
    let typeID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemTypeID FROM itemTypes WHERE typeName = 'note'`
    ));
    let key = await this.uniqueKey('items', title);
    await this.db.executeTransaction(async (): Promise<void> => {
      await this.db.executeSql(
        `INSERT INTO items (itemTypeID, libraryID, key, version, synced)
         VALUES (?, 1, ?, 0, 0)`,
        [typeID > 0 ? typeID : 8, key]
      );
      let itemID = this.toNumber(await this.db.valueQueryAsync(
        `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [key]
      ));
      await this.db.executeSql(
        `INSERT INTO itemNotes (itemID, parentItemID, note, title)
         VALUES (?, ?, ?, ?)`,
        [itemID, parentID, noteText, title]
      );
      await this.putItemField(itemID, 'title', title);
      await this.putItemField(itemID, 'note', noteText);
      await this.putItemField(itemID, 'itemType', 'note');
    });
    await this.addToSyncQueue(1, 'item', [key]);
    return key;
  }

  async updateNote(noteID: number, title: string, noteText: string): Promise<void> {
    let itemKey = this.toString(await this.db.valueQueryAsync(
      `SELECT key FROM items WHERE itemID = ?`, [noteID]
    ), '');
    if (itemKey.length === 0) {
      return;
    }
    await this.db.executeTransaction(async (): Promise<void> => {
      await this.db.executeSql(
        `UPDATE itemNotes SET title = ?, note = ? WHERE itemID = ?`,
        [title, noteText, noteID]
      );
      await this.putItemField(noteID, 'title', title);
      await this.putItemField(noteID, 'note', noteText);
      await this.db.executeSql(
        `UPDATE items SET synced = 0, clientDateModified = datetime('now'), dateModified = datetime('now')
         WHERE itemID = ?`,
        [noteID]
      );
    });
    await this.addToSyncQueue(1, 'item', [itemKey]);
  }

  async deleteNote(noteID: number): Promise<void> {
    let itemKey = this.toString(await this.db.valueQueryAsync(
      `SELECT key FROM items WHERE itemID = ?`, [noteID]
    ), '');
    if (itemKey.length === 0) {
      return;
    }
    await this.moveItemToTrash(itemKey);
  }

  async createLinkedUrlAttachment(parentItemKey: string, url: string): Promise<string> {
    let parentID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [parentItemKey]
    ));
    if (parentID === 0) {
      return '';
    }
    let typeID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemTypeID FROM itemTypes WHERE typeName = 'attachment'`
    ));
    let key = await this.uniqueKey('items', url);
    await this.db.executeTransaction(async (): Promise<void> => {
      await this.db.executeSql(
        `INSERT INTO items (itemTypeID, libraryID, key, version, synced)
         VALUES (?, 1, ?, 0, 0)`,
        [typeID > 0 ? typeID : 9, key]
      );
      let itemID = this.toNumber(await this.db.valueQueryAsync(
        `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [key]
      ));
      await this.db.executeSql(
        `INSERT OR REPLACE INTO itemAttachments
         (itemID, parentItemID, linkMode, contentType, path, syncState)
         VALUES (?, ?, 3, 'text/html', ?, 0)`,
        [itemID, parentID, url]
      );
      await this.putItemField(itemID, 'title', url);
      await this.putItemField(itemID, 'url', url);
      await this.putItemField(itemID, 'itemType', 'attachment');
    });
    await this.addToSyncQueue(1, 'item', [key]);
    return key;
  }

  async deleteAttachment(itemKey: string): Promise<void> {
    await this.moveItemToTrash(itemKey);
  }

  async createImportedFileAttachment(parentItemKey: string, sourceUri: string, appContext: Context): Promise<string> {
    let parentID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [parentItemKey]
    ));
    if (parentID === 0 || sourceUri.length === 0) {
      return '';
    }
    let typeID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemTypeID FROM itemTypes WHERE typeName = 'attachment'`
    ));
    let sourceName = this.fileNameFromUri(sourceUri);
    let key = await this.uniqueKey('items', sourceName);
    let storage = new FileStorage(appContext.filesDir ?? '');
    let contentType = this.guessContentType(sourceName);
    let stored = await storage.importFile(sourceUri, key, contentType);
    await this.db.executeTransaction(async (): Promise<void> => {
      await this.db.executeSql(
        `INSERT INTO items (itemTypeID, libraryID, key, version, synced)
         VALUES (?, 1, ?, 0, 0)`,
        [typeID > 0 ? typeID : 9, key]
      );
      let itemID = this.toNumber(await this.db.valueQueryAsync(
        `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [key]
      ));
      await this.db.executeSql(
        `INSERT OR REPLACE INTO itemAttachments
         (itemID, parentItemID, linkMode, contentType, path, syncState)
         VALUES (?, ?, 0, ?, ?, 0)`,
        [itemID, parentID, stored.contentType, stored.localPath]
      );
      await this.putItemField(itemID, 'title', sourceName);
      await this.putItemField(itemID, 'filename', sourceName);
      await this.putItemField(itemID, 'path', stored.localPath);
      await this.putItemField(itemID, 'itemType', 'attachment');
    });
    await this.addToSyncQueue(1, 'item', [key]);
    return key;
  }

  async importItems(items: ItemModel[], collectionKey: string | null): Promise<string[]> {
    let importedKeys: string[] = [];
    for (let i = 0; i < items.length; i++) {
      let source = items[i];
      let title = source.itemData.get('title') ?? 'Imported Item';
      let itemType = source.itemData.get('itemType') ?? source.itemData.get('type') ?? 'journalArticle';
      let key = await this.createItem(collectionKey, itemType, title);
      importedKeys.push(key);
      let itemData = source.itemData;
      let fieldNames: string[] = [];
      let values: string[] = [];
      itemData.forEach((value: string, fieldName: string) => {
        fieldNames.push(fieldName);
        values.push(value);
      });
      for (let j = 0; j < fieldNames.length; j++) {
        await this.updateItemField(key, fieldNames[j], values[j]);
      }
    }
    return importedKeys;
  }

  async createSavedSearch(name: string, conditions: SavedSearchConditionData[]): Promise<string> {
    let key = await this.uniqueKey('savedSearches', name);
    await this.db.executeTransaction(async (): Promise<void> => {
      await this.db.executeSql(
        `INSERT INTO savedSearches (savedSearchName, libraryID, key, synced)
         VALUES (?, 1, ?, 0)`,
        [name, key]
      );
      let savedSearchID = this.toNumber(await this.db.valueQueryAsync(
        `SELECT savedSearchID FROM savedSearches WHERE libraryID = 1 AND key = ?`,
        [key]
      ));
      for (let i = 0; i < conditions.length; i++) {
        await this.db.executeSql(
          `INSERT INTO savedSearchConditions
           (savedSearchID, searchConditionID, condition, operator, value, required)
           VALUES (?, ?, ?, ?, ?, ?)`,
          [
            savedSearchID,
            i + 1,
            conditions[i].condition,
            conditions[i].operator,
            conditions[i].value,
            conditions[i].required ? 1 : 0,
          ]
        );
      }
    });
    await this.addToSyncQueue(1, 'search', [key]);
    return key;
  }

  async getSavedSearchQuery(searchKey: string): Promise<SavedSearchQueryData | null> {
    if (searchKey.length === 0) {
      return null;
    }
    let rows = await this.db.queryAsync(
      `SELECT s.savedSearchID, s.savedSearchName, sc.searchConditionID, sc.condition, sc.operator, sc.value, sc.required
       FROM savedSearches s
       LEFT JOIN savedSearchConditions sc ON sc.savedSearchID = s.savedSearchID
       WHERE s.libraryID = 1 AND s.key = ?
       ORDER BY sc.searchConditionID`,
      [searchKey]
    );
    if (rows.length === 0) {
      return null;
    }
    let searchName = this.toString(rows[0]['savedSearchName'], 'Saved Search');
    let joinMode: JoinMode = 'all';
    let conditions: SearchCondition[] = [];
    for (let i = 0; i < rows.length; i++) {
      let condition = this.toString(rows[i]['condition'], '');
      let operator = this.toString(rows[i]['operator'], '');
      let value = this.toString(rows[i]['value'], '');
      if (condition === 'joinMode') {
        joinMode = value === 'any' ? 'any' : 'all';
        continue;
      }
      if (condition.length === 0) {
        continue;
      }
      conditions.push({
        id: conditions.length + 1,
        condition: condition,
        operator: operator,
        value: value,
        required: this.toNumber(rows[i]['required']) > 0,
      });
    }
    return {
      key: searchKey,
      name: searchName,
      joinMode: joinMode,
      conditions: conditions,
    };
  }

  async updateItemField(itemKey: string, fieldName: string, value: string): Promise<void> {
    let itemID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [itemKey]
    ));
    if (itemID === 0) {
      return;
    }
    if (value.length === 0) {
      // Delete the field entry
      let fieldID = this.toNumber(await this.db.valueQueryAsync(
        `SELECT fieldID FROM fields WHERE fieldName = ?`, [fieldName]
      ));
      if (fieldID > 0) {
        await this.db.executeSql(
          `DELETE FROM itemData WHERE itemID = ? AND fieldID = ?`, [itemID, fieldID]
        );
      }
    } else {
      await this.putItemField(itemID, fieldName, value);
    }
    await this.db.executeSql(
      `UPDATE items SET synced = 0, clientDateModified = datetime('now'), dateModified = datetime('now')
       WHERE itemID = ?`,
      [itemID]
    );
    await this.addToSyncQueue(1, 'item', [itemKey]);
  }

  /** Change an item's type (updates itemTypeID + itemData['itemType']). */
  async updateItemTypeByKey(itemKey: string, newItemType: string): Promise<void> {
    let itemID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [itemKey]
    ));
    if (itemID === 0) { return; }
    let typeID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemTypeID FROM itemTypes WHERE typeName = ?`, [newItemType]
    ));
    if (typeID === 0) { typeID = 1; }
    await this.db.executeSql(
      `UPDATE items SET itemTypeID = ?, synced = 0, clientDateModified = datetime('now'),
       dateModified = datetime('now') WHERE itemID = ?`,
      [typeID, itemID]
    );
    await this.putItemField(itemID, 'itemType', newItemType);
    await this.addToSyncQueue(1, 'item', [itemKey]);
  }

  async replaceItemTags(itemKey: string, tags: ZoteroTag[]): Promise<void> {
    let itemID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [itemKey]
    ));
    if (itemID === 0) {
      return;
    }
    await this.db.executeTransaction(async (): Promise<void> => {
      await this.db.executeSql(`DELETE FROM itemTags WHERE itemID = ?`, [itemID]);
      for (let i = 0; i < tags.length; i++) {
        await this.db.executeSql(
          `INSERT OR IGNORE INTO tags (name) VALUES (?)`, [tags[i].tag]
        );
        let tagID = this.toNumber(await this.db.valueQueryAsync(
          `SELECT tagID FROM tags WHERE name = ?`, [tags[i].tag]
        ));
        await this.db.executeSql(
          `INSERT OR REPLACE INTO itemTags (itemID, tagID, type) VALUES (?, ?, ?)`,
          [itemID, tagID, tags[i].type]
        );
      }
      await this.db.executeSql(
        `UPDATE items SET synced = 0, clientDateModified = datetime('now') WHERE itemID = ?`,
        [itemID]
      );
    });
    await this.addToSyncQueue(1, 'item', [itemKey]);
  }

  async listItemCollectionKeys(itemKey: string): Promise<string[]> {
    let itemID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [itemKey]
    ));
    if (itemID === 0) {
      return [];
    }
    let rows = await this.db.queryAsync(
      `SELECT c.key
       FROM collectionItems ci
       JOIN collections c ON c.collectionID = ci.collectionID
       WHERE ci.itemID = ?
       ORDER BY c.collectionName`,
      [itemID]
    );
    let keys: string[] = [];
    for (let i = 0; i < rows.length; i++) {
      let key = this.toString(rows[i]['key'], '');
      if (key.length > 0) {
        keys.push(key);
      }
    }
    return keys;
  }

  async replaceItemCollections(itemKey: string, collectionKeys: string[]): Promise<void> {
    let itemID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [itemKey]
    ));
    if (itemID === 0) {
      return;
    }
    await this.db.executeTransaction(async (): Promise<void> => {
      await this.db.executeSql(`DELETE FROM collectionItems WHERE itemID = ?`, [itemID]);
      for (let i = 0; i < collectionKeys.length; i++) {
        let collectionID = this.toNumber(await this.db.valueQueryAsync(
          `SELECT collectionID FROM collections WHERE libraryID = 1 AND key = ?`,
          [collectionKeys[i]]
        ));
        if (collectionID > 0) {
          await this.db.executeSql(
            `INSERT OR IGNORE INTO collectionItems (collectionID, itemID) VALUES (?, ?)`,
            [collectionID, itemID]
          );
        }
      }
    });
    await this.addToSyncQueue(1, 'item', [itemKey]);
  }

  async listRelatedItems(itemKey: string): Promise<RelatedItemRef[]> {
    let relatedKeys = await this._listRelatedItemKeys(itemKey);
    if (relatedKeys.length === 0) {
      return [];
    }
    let relatedItems = await this.getItemsByKeys(relatedKeys);
    let itemMap: Map<string, ItemModel> = new Map();
    for (let i = 0; i < relatedItems.length; i++) {
      let key = relatedItems[i].key ?? '';
      if (key.length > 0) {
        itemMap.set(key, relatedItems[i]);
      }
    }
    let refs: RelatedItemRef[] = [];
    for (let i = 0; i < relatedKeys.length; i++) {
      let item = itemMap.get(relatedKeys[i]);
      if (!item) {
        continue;
      }
      refs.push({
        key: item.key ?? '',
        title: item.displayTitle ?? item.itemData.get('title') ?? '(untitled)',
        itemType: item.itemData.get('itemType') ?? '',
        creators: item.itemData.get('creator') ?? '',
      });
    }
    return refs;
  }

  async addRelatedItems(itemKey: string, relatedKeys: string[]): Promise<void> {
    if (itemKey.length === 0 || relatedKeys.length === 0) {
      return;
    }
    let itemID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [itemKey]
    ));
    if (itemID === 0) {
      return;
    }
    await this.db.executeTransaction(async (): Promise<void> => {
      for (let i = 0; i < relatedKeys.length; i++) {
        let relatedKey = relatedKeys[i];
        if (relatedKey.length === 0 || relatedKey === itemKey) {
          continue;
        }
        let relatedID = this.toNumber(await this.db.valueQueryAsync(
          `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [relatedKey]
        ));
        if (relatedID === 0) {
          continue;
        }
        await this.db.executeSql(
          `INSERT OR IGNORE INTO itemRelations (itemID, relatedItemID) VALUES (?, ?)`,
          [itemID, relatedID]
        );
        await this.db.executeSql(
          `INSERT OR IGNORE INTO itemRelations (itemID, relatedItemID) VALUES (?, ?)`,
          [relatedID, itemID]
        );
      }
      await this.db.executeSql(
        `UPDATE items SET synced = 0, clientDateModified = datetime('now') WHERE itemID = ?`,
        [itemID]
      );
    });
  }

  async removeRelatedItem(itemKey: string, relatedKey: string): Promise<void> {
    if (itemKey.length === 0 || relatedKey.length === 0) {
      return;
    }
    let itemID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [itemKey]
    ));
    let relatedID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [relatedKey]
    ));
    if (itemID === 0 || relatedID === 0) {
      return;
    }
    await this.db.executeTransaction(async (): Promise<void> => {
      await this.db.executeSql(
        `DELETE FROM itemRelations WHERE itemID = ? AND relatedItemID = ?`,
        [itemID, relatedID]
      );
      await this.db.executeSql(
        `DELETE FROM itemRelations WHERE itemID = ? AND relatedItemID = ?`,
        [relatedID, itemID]
      );
      await this.db.executeSql(
        `UPDATE items SET synced = 0, clientDateModified = datetime('now') WHERE itemID = ?`,
        [itemID]
      );
      await this.db.executeSql(
        `UPDATE items SET synced = 0, clientDateModified = datetime('now') WHERE itemID = ?`,
        [relatedID]
      );
    });
  }

  /**
   * Return child rows (attachments, notes) for the given parent item keys.
   * Excludes items in deletedItems.  Does not fetch annotations (TODO).
   */
  async listChildRowsForItems(parentKeys: string[]): Promise<ItemChildSummary[]> {
    if (parentKeys.length === 0) { return []; }
    let results: ItemChildSummary[] = [];

    // Build parentKey→parentItemID map
    let parentIDs: number[] = [];
    let idToKey = new Map<number, string>();
    for (let i = 0; i < parentKeys.length; i++) {
      let pid = this.toNumber(await this.db.valueQueryAsync(
        `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [parentKeys[i]]
      ));
      if (pid > 0) {
        parentIDs.push(pid);
        idToKey.set(pid, parentKeys[i]);
      }
    }
    if (parentIDs.length === 0) { return results; }

    // Attachments
    let attRows = await this.db.queryAsync(
      `SELECT i.key, ia.parentItemID, ia.contentType, ia.path,
              COALESCE(
                (SELECT v.value FROM itemData d
                 JOIN itemDataValues v ON v.valueID = d.valueID
                 JOIN fields f ON f.fieldID = d.fieldID
                 WHERE d.itemID = i.itemID AND f.fieldName = 'title'),
                ia.path,
                'Attachment'
              ) AS title
       FROM itemAttachments ia
       JOIN items i ON i.itemID = ia.itemID
       WHERE ia.parentItemID IN (${parentIDs.join(',')})
         AND NOT EXISTS (SELECT 1 FROM deletedItems di WHERE di.itemID = i.itemID)
       ORDER BY i.dateAdded`
    );
    for (let i = 0; i < attRows.length; i++) {
      let pidKey = idToKey.get(this.toNumber(attRows[i]['parentItemID'])) ?? '';
      results.push({
        key: this.toString(attRows[i]['key'], ''),
        parentKey: pidKey,
        childType: 'attachment',
        title: this.toString(attRows[i]['title'], 'Attachment'),
        subtitle: this.toString(attRows[i]['contentType'], ''),
        sortIndex: '',
      });
    }

    // Notes
    let noteRows = await this.db.queryAsync(
      `SELECT i.key, n.parentItemID, n.title,
              COALESCE(n.title, substr(n.note, 1, 80), 'Note') AS displayTitle,
              i.dateModified
       FROM itemNotes n
       JOIN items i ON i.itemID = n.itemID
       WHERE n.parentItemID IN (${parentIDs.join(',')})
         AND NOT EXISTS (SELECT 1 FROM deletedItems di WHERE di.itemID = i.itemID)
       ORDER BY i.dateModified DESC`
    );
    for (let i = 0; i < noteRows.length; i++) {
      let pidKey = idToKey.get(this.toNumber(noteRows[i]['parentItemID'])) ?? '';
      results.push({
        key: this.toString(noteRows[i]['key'], ''),
        parentKey: pidKey,
        childType: 'note',
        title: this.toString(noteRows[i]['displayTitle'], 'Note'),
        subtitle: this.toString(noteRows[i]['dateModified'], ''),
        sortIndex: '',
      });
    }

    // TODO: annotations — itemAnnotations.parentItemID points to the
    // attachment item, not the regular item.  Three-level tree
    // (regular→attachment→annotation) requires a second query pass.
    // For now, annotations are not shown in the item tree.

    return results;
  }

  async addItemsToCollection(itemKeys: string[], collectionKey: string): Promise<void> {
    if (itemKeys.length === 0 || collectionKey.length === 0) {
      return;
    }
    let collectionID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT collectionID FROM collections WHERE libraryID = 1 AND key = ?`,
      [collectionKey]
    ));
    if (collectionID === 0) {
      return;
    }
    await this.db.executeTransaction(async (): Promise<void> => {
      for (let i = 0; i < itemKeys.length; i++) {
        let itemID = this.toNumber(await this.db.valueQueryAsync(
          `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`,
          [itemKeys[i]]
        ));
        if (itemID === 0) {
          continue;
        }
        await this.db.executeSql(
          `INSERT OR IGNORE INTO collectionItems (collectionID, itemID) VALUES (?, ?)`,
          [collectionID, itemID]
        );
        await this.db.executeSql(
          `UPDATE items SET synced = 0, clientDateModified = datetime('now') WHERE itemID = ?`,
          [itemID]
        );
      }
    });
    await this.addToSyncQueue(1, 'item', itemKeys);
  }

  async mergeItems(itemKeys: string[]): Promise<string | null> {
    let items = await this.getItemsByKeys(itemKeys);
    if (items.length < 2) {
      return null;
    }
    let survivor = items[0];
    let survivorKey = survivor.key ?? '';
    if (survivorKey.length === 0) {
      return null;
    }
    let survivorTags = await this.getItemTags(survivorKey);
    let survivorCollections = await this.listItemCollectionKeys(survivorKey);
    let mergedTagMap: Map<string, ZoteroTag> = new Map();
    for (let i = 0; i < survivorTags.length; i++) {
      mergedTagMap.set(survivorTags[i].tag, survivorTags[i]);
    }
    let mergedCollections: string[] = [...survivorCollections];

    for (let i = 1; i < items.length; i++) {
      let source = items[i];
      let sourceKey = source.key ?? '';
      if (sourceKey.length === 0) {
        continue;
      }
      let fieldNames: string[] = [];
      source.itemData.forEach((_value: string, fieldName: string) => {
        fieldNames.push(fieldName);
      });
      for (let j = 0; j < fieldNames.length; j++) {
        let fieldName = fieldNames[j];
        if ((survivor.itemData.get(fieldName) ?? '').length === 0) {
          await this.updateItemField(survivorKey, fieldName, source.itemData.get(fieldName) ?? '');
        }
      }
      let sourceTags = await this.getItemTags(sourceKey);
      for (let t = 0; t < sourceTags.length; t++) {
        mergedTagMap.set(sourceTags[t].tag, sourceTags[t]);
      }
      let sourceCollections = await this.listItemCollectionKeys(sourceKey);
      for (let c = 0; c < sourceCollections.length; c++) {
        if (mergedCollections.indexOf(sourceCollections[c]) < 0) {
          mergedCollections.push(sourceCollections[c]);
        }
      }
    }

    await this.replaceItemTags(survivorKey, Array.from(mergedTagMap.values()));
    await this.replaceItemCollections(survivorKey, mergedCollections);

    for (let i = 1; i < items.length; i++) {
      let sourceKey = items[i].key ?? '';
      if (sourceKey.length > 0) {
        await this.moveItemToTrash(sourceKey);
      }
    }
    return survivorKey;
  }

  async listPendingStorageRequests(): Promise<StorageRequest[]> {
    let rows = await this.db.queryAsync(
      `SELECT i.itemID, i.key, ia.linkMode, ia.path, ia.contentType, ia.syncState
       FROM itemAttachments ia
       JOIN items i ON i.itemID = ia.itemID
       WHERE ia.syncState != 1
       ORDER BY i.dateModified DESC`
    );
    let requests: StorageRequest[] = [];
    for (let i = 0; i < rows.length; i++) {
      requests.push({
        itemID: this.toNumber(rows[i]['itemID']),
        itemKey: this.toString(rows[i]['key'], ''),
        operation: 'download',
        linkMode: this.toNumber(rows[i]['linkMode']),
        path: this.toString(rows[i]['path'], ''),
        contentType: this.toString(rows[i]['contentType'], ''),
      });
    }
    return requests;
  }

  async updateAttachmentSyncState(itemID: number, syncState: number): Promise<void> {
    await this.db.executeSql(
      `UPDATE itemAttachments SET syncState = ? WHERE itemID = ?`,
      [syncState, itemID]
    );
  }

  async updateAttachmentPath(itemID: number, path: string): Promise<void> {
    await this.db.executeSql(
      `UPDATE itemAttachments SET path = ?, synced = 0 WHERE itemID = ?`,
      [path, itemID]
    );
  }

  async moveItemToTrash(itemKey: string): Promise<void> {
    let itemID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [itemKey]
    ));
    if (itemID === 0) {
      return;
    }
    await this.db.executeTransaction(async (): Promise<void> => {
      await this.db.executeSql(
        `INSERT OR REPLACE INTO deletedItems (itemID, dateDeleted) VALUES (?, datetime('now'))`,
        [itemID]
      );
      await this.db.executeSql(
        `UPDATE items SET synced = 0, clientDateModified = datetime('now') WHERE itemID = ?`,
        [itemID]
      );
    });
    // TODO: distinguish trash (item upsert) from permanent-delete (deleteLog)
    await this.addToSyncQueue(1, 'item', [itemKey]);
  }

  async moveItemsToTrash(itemKeys: string[]): Promise<void> {
    for (let i = 0; i < itemKeys.length; i++) {
      await this.moveItemToTrash(itemKeys[i]);
    }
  }

  async restoreItemsFromTrash(itemKeys: string[]): Promise<void> {
    for (let i = 0; i < itemKeys.length; i++) {
      let itemID = this.toNumber(await this.db.valueQueryAsync(
        `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [itemKeys[i]]
      ));
      if (itemID === 0) {
        continue;
      }
      await this.db.executeTransaction(async (): Promise<void> => {
        await this.db.executeSql(`DELETE FROM deletedItems WHERE itemID = ?`, [itemID]);
        await this.db.executeSql(
          `UPDATE items SET synced = 0, clientDateModified = datetime('now') WHERE itemID = ?`,
          [itemID]
        );
      });
    }
    await this.addToSyncQueue(1, 'item', itemKeys);
  }

  async upsertRemoteObject(objectType: RemoteObjectType, object: Record<string, Object>, libraryID: number = 1): Promise<void> {
    let data = this.remoteData(object);
    let key = this.remoteString(object, 'key', this.remoteString(data, 'key', ''));
    let version = this.remoteNumber(object, 'version', this.remoteNumber(data, 'version', 0));
    if (key.length === 0) {
      return;
    }
    await this.db.executeTransaction(async (): Promise<void> => {
      if (objectType === 'collection') {
        await this.upsertRemoteCollection(key, version, data, libraryID);
      } else if (objectType === 'search') {
        await this.upsertRemoteSearch(key, version, data, libraryID);
      } else {
        await this.upsertRemoteItem(key, version, data, libraryID);
      }
    });
  }

  async applyRemoteDeletions(objectType: RemoteObjectType, keys: string[], libraryID: number = 1): Promise<void> {
    for (let i = 0; i < keys.length; i++) {
      if (objectType === 'item') {
        let itemID = this.toNumber(await this.db.valueQueryAsync(
          `SELECT itemID FROM items WHERE libraryID = ? AND key = ?`, [libraryID, keys[i]]
        ));
        if (itemID > 0) {
          await this.db.executeSql(
            `INSERT OR REPLACE INTO deletedItems (itemID, dateDeleted) VALUES (?, datetime('now'))`,
            [itemID]
          );
        }
      } else if (objectType === 'collection') {
        await this.db.executeSql(
          `DELETE FROM collections WHERE libraryID = ? AND key = ?`, [libraryID, keys[i]]
        );
      } else {
        await this.db.executeSql(
          `DELETE FROM savedSearches WHERE libraryID = ? AND key = ?`, [libraryID, keys[i]]
        );
      }
    }
  }

  // ==================================================================
  // Sync Queue / Delete Log — persistent local-change tracking
  // ==================================================================

  /**
   * Enqueue local upserts.  Called by create/update methods.
   * Only call from LOCAL mutation methods — NEVER from remote upsert methods.
   */
  async addToSyncQueue(libraryID: number, objectType: RemoteObjectType, keys: string[]): Promise<void> {
    if (keys.length === 0) { return; }
    await this.db.executeTransaction(async (): Promise<void> => {
      for (let i = 0; i < keys.length; i++) {
        await this.db.executeSql(
          `INSERT OR REPLACE INTO syncQueue
           (libraryID, objectType, key, operation, tries, lastTryTimestamp,
            dateAdded, dateModified)
           VALUES (
             ?, ?, ?, 'upsert', 0, 0,
             COALESCE((SELECT dateAdded FROM syncQueue
                       WHERE libraryID = ? AND objectType = ? AND key = ? AND operation = 'upsert'),
                      datetime('now')),
             datetime('now')
           )`,
          [libraryID, objectType, keys[i], libraryID, objectType, keys[i]]
        );
      }
    });
  }

  /** Remove keys from the sync queue (after successful upload). */
  async removeFromSyncQueue(libraryID: number, objectType: RemoteObjectType, keys: string[]): Promise<void> {
    if (keys.length === 0) { return; }
    await this.db.executeTransaction(async (): Promise<void> => {
      for (let i = 0; i < keys.length; i++) {
        await this.db.executeSql(
          `DELETE FROM syncQueue
           WHERE libraryID = ? AND objectType = ? AND key = ? AND operation = 'upsert'`,
          [libraryID, objectType, keys[i]]
        );
      }
    });
  }

  /** Return all queued upsert keys for a given library+objectType. */
  async getAllObjectsInQueue(libraryID: number, objectType: RemoteObjectType): Promise<string[]> {
    let rows = await this.db.queryAsync(
      `SELECT key FROM syncQueue
       WHERE libraryID = ? AND objectType = ? AND operation = 'upsert'
       ORDER BY dateAdded`,
      [libraryID, objectType]
    );
    let keys: string[] = [];
    for (let i = 0; i < rows.length; i++) {
      keys.push(this.toString(rows[i]['key'], ''));
    }
    return keys;
  }

  /** Record local deletions for upload.  Also removes from syncQueue. */
  async addToDeleteLog(libraryID: number, objectType: RemoteObjectType, keys: string[]): Promise<void> {
    if (keys.length === 0) { return; }
    await this.db.executeTransaction(async (): Promise<void> => {
      for (let i = 0; i < keys.length; i++) {
        // Remove any pending upsert for the same object (avoid upload-then-delete)
        await this.db.executeSql(
          `DELETE FROM syncQueue
           WHERE libraryID = ? AND objectType = ? AND key = ?`,
          [libraryID, objectType, keys[i]]
        );
        await this.db.executeSql(
          `INSERT OR REPLACE INTO syncDeleteLog
           (libraryID, objectType, key, dateDeleted)
           VALUES (?, ?, ?, datetime('now'))`,
          [libraryID, objectType, keys[i]]
        );
      }
    });
  }

  /** Return keys currently in the delete log. */
  async getDeleted(libraryID: number, objectType: RemoteObjectType): Promise<string[]> {
    let rows = await this.db.queryAsync(
      `SELECT key FROM syncDeleteLog
       WHERE libraryID = ? AND objectType = ?
       ORDER BY dateDeleted`,
      [libraryID, objectType]
    );
    let keys: string[] = [];
    for (let i = 0; i < rows.length; i++) {
      keys.push(this.toString(rows[i]['key'], ''));
    }
    return keys;
  }

  /** Remove keys from the delete log (after upload confirmed). */
  async removeFromDeleteLog(libraryID: number, objectType: RemoteObjectType, keys: string[]): Promise<void> {
    if (keys.length === 0) { return; }
    await this.db.executeTransaction(async (): Promise<void> => {
      for (let i = 0; i < keys.length; i++) {
        await this.db.executeSql(
          `DELETE FROM syncDeleteLog
           WHERE libraryID = ? AND objectType = ? AND key = ?`,
          [libraryID, objectType, keys[i]]
        );
      }
    });
  }

  /** Check if there are any pending local changes. */
  async hasPendingLocalChanges(libraryID: number): Promise<boolean> {
    let qCount = this.toNumber(await this.db.valueQueryAsync(
      `SELECT COUNT(*) FROM syncQueue WHERE libraryID = ?`, [libraryID]
    ));
    let dCount = this.toNumber(await this.db.valueQueryAsync(
      `SELECT COUNT(*) FROM syncDeleteLog WHERE libraryID = ?`, [libraryID]
    ));
    return qCount > 0 || dCount > 0;
  }

  // ==================================================================
  // Upload serialization — build Zotero Web API v3 objects from local DB
  // ==================================================================

  /** Dispatch to type-specific serializer.  Does NOT touch syncQueue. */
  async getObjectsForUpload(libraryID: number, objectType: RemoteObjectType, keys: string[]): Promise<Record<string, Object>[]> {
    if (keys.length === 0) { return []; }
    if (objectType === 'collection') {
      return this.getCollectionsForUpload(libraryID, keys);
    }
    if (objectType === 'search') {
      return this.getSearchesForUpload(libraryID, keys);
    }
    return this.getItemsForUpload(libraryID, keys);
  }

  private async getCollectionsForUpload(libraryID: number, keys: string[]): Promise<Record<string, Object>[]> {
    let results: Record<string, Object>[] = [];
    for (let i = 0; i < keys.length; i++) {
      let rows = await this.db.queryAsync(
        `SELECT collectionID, collectionName, parentCollectionID, key, version
         FROM collections WHERE libraryID = ? AND key = ?`,
        [libraryID, keys[i]]
      );
      if (rows.length === 0) { continue; }
      let name = this.toString(rows[0]['collectionName'], 'Untitled');
      let version = this.toNumber(rows[0]['version']);
      let parentID = this.toNullableNumber(rows[0]['parentCollectionID']);
      let parentKey: string | boolean = false;
      if (parentID !== null) {
        let pk = await this.db.valueQueryAsync(
          `SELECT key FROM collections WHERE collectionID = ?`, [parentID]
        );
        parentKey = this.toString(pk, '');
        if ((parentKey as string).length === 0) { parentKey = false; }
      }
      results.push({ key: keys[i], version, name, parentCollection: parentKey });
    }
    return results;
  }

  private async getSearchesForUpload(libraryID: number, keys: string[]): Promise<Record<string, Object>[]> {
    let results: Record<string, Object>[] = [];
    for (let i = 0; i < keys.length; i++) {
      let rows = await this.db.queryAsync(
        `SELECT savedSearchID, savedSearchName, key, version
         FROM savedSearches WHERE libraryID = ? AND key = ?`,
        [libraryID, keys[i]]
      );
      if (rows.length === 0) { continue; }
      let name = this.toString(rows[0]['savedSearchName'], 'Saved Search');
      let version = this.toNumber(rows[0]['version']);
      let savedSearchID = this.toNumber(rows[0]['savedSearchID']);
      let condRows = await this.db.queryAsync(
        `SELECT condition, operator, value, required
         FROM savedSearchConditions WHERE savedSearchID = ? ORDER BY searchConditionID`,
        [savedSearchID]
      );
      let conditions: Record<string, Object>[] = [];
      for (let c = 0; c < condRows.length; c++) {
        conditions.push({
          condition: this.toString(condRows[c]['condition'], ''),
          operator: this.toString(condRows[c]['operator'], ''),
          value: this.toString(condRows[c]['value'], ''),
          required: this.toNumber(condRows[c]['required']) > 0,
        });
      }
      results.push({ key: keys[i], version, name, conditions });
    }
    return results;
  }

  private async getItemsForUpload(libraryID: number, keys: string[]): Promise<Record<string, Object>[]> {
    let results: Record<string, Object>[] = [];
    for (let ki = 0; ki < keys.length; ki++) {
      let itemKey = keys[ki];
      let itemRows = await this.db.queryAsync(
        `SELECT i.itemID, i.key, i.version, i.dateAdded, i.dateModified,
                it.typeName AS itemType
         FROM items i
         JOIN itemTypes it ON it.itemTypeID = i.itemTypeID
         WHERE i.libraryID = ? AND i.key = ?`,
        [libraryID, itemKey]
      );
      if (itemRows.length === 0) { continue; }
      let itemID = this.toNumber(itemRows[0]['itemID']);
      let itemType = this.toString(itemRows[0]['itemType'], 'journalArticle');
      let version = this.toNumber(itemRows[0]['version']);
      let obj: Record<string, Object> = {
        key: itemKey, version, itemType,
      };

      // Scalar fields (top-level, per Zotero API)
      let fieldRows = await this.db.queryAsync(
        `SELECT f.fieldName, v.value
         FROM itemData d
         JOIN fields f ON f.fieldID = d.fieldID
         JOIN itemDataValues v ON v.valueID = d.valueID
         WHERE d.itemID = ?`,
        [itemID]
      );
      for (let fi = 0; fi < fieldRows.length; fi++) {
        let fieldName = this.toString(fieldRows[fi]['fieldName'], '');
        // Skip structural pseudo-fields stored in itemData for convenience
        if (fieldName === 'itemType' || fieldName === 'creator' || fieldName === 'note') {
          continue;
        }
        obj[fieldName] = this.toString(fieldRows[fi]['value'], '');
      }

      // Creators
      let creatorRows = await this.db.queryAsync(
        `SELECT cr.firstName, cr.lastName, cr.fieldMode, ct.creatorType, ic.orderIndex
         FROM itemCreators ic
         JOIN creators cr ON cr.creatorID = ic.creatorID
         LEFT JOIN creatorTypes ct ON ct.creatorTypeID = ic.creatorTypeID
         WHERE ic.itemID = ?
         ORDER BY ic.orderIndex`,
        [itemID]
      );
      if (creatorRows.length > 0) {
        let creators: Record<string, Object>[] = [];
        for (let ci = 0; ci < creatorRows.length; ci++) {
          let cr: Record<string, Object> = {
            creatorType: this.toString(creatorRows[ci]['creatorType'], 'author'),
          };
          let fm = this.toNumber(creatorRows[ci]['fieldMode']);
          if (fm === 1) {
            cr['name'] = this.toString(creatorRows[ci]['lastName'], '');
          } else {
            cr['firstName'] = this.toString(creatorRows[ci]['firstName'], '');
            cr['lastName'] = this.toString(creatorRows[ci]['lastName'], '');
          }
          creators.push(cr);
        }
        obj['creators'] = creators;
      }

      // Tags
      let tagRows = await this.db.queryAsync(
        `SELECT t.name, it.type
         FROM itemTags it JOIN tags t ON t.tagID = it.tagID
         WHERE it.itemID = ? ORDER BY t.name`,
        [itemID]
      );
      if (tagRows.length > 0) {
        let tags: Record<string, Object>[] = [];
        for (let ti2 = 0; ti2 < tagRows.length; ti2++) {
          tags.push({
            tag: this.toString(tagRows[ti2]['name'], ''),
            type: this.toNumber(tagRows[ti2]['type']),
          });
        }
        obj['tags'] = tags;
      }

      // Collections
      let colRows = await this.db.queryAsync(
        `SELECT c.key
         FROM collectionItems ci
         JOIN collections c ON c.collectionID = ci.collectionID
         WHERE ci.itemID = ?
         ORDER BY c.collectionName`,
        [itemID]
      );
      if (colRows.length > 0) {
        let cols: string[] = [];
        for (let ci2 = 0; ci2 < colRows.length; ci2++) {
          cols.push(this.toString(colRows[ci2]['key'], ''));
        }
        obj['collections'] = cols;
      }

      // Relations
      let relRows = await this.db.queryAsync(
        `SELECT i2.key
         FROM itemRelations r JOIN items i2 ON i2.itemID = r.relatedItemID
         WHERE r.itemID = ?`,
        [itemID]
      );
      if (relRows.length > 0) {
        let relKeys: string[] = [];
        for (let ri = 0; ri < relRows.length; ri++) {
          relKeys.push(this.toString(relRows[ri]['key'], ''));
        }
        obj['relations'] = { 'dc:relation': relKeys };
      }

      // Subtype tables
      if (itemType === 'note') {
        let noteRows = await this.db.queryAsync(
          `SELECT parentItemID, note, title FROM itemNotes WHERE itemID = ?`,
          [itemID]
        );
        if (noteRows.length > 0) {
          obj['note'] = this.toString(noteRows[0]['note'], '');
          let noteTitle = this.toString(noteRows[0]['title'], '');
          if (noteTitle.length > 0) { obj['title'] = noteTitle; }
          let parentNoteID = this.toNullableNumber(noteRows[0]['parentItemID']);
          if (parentNoteID !== null) {
            let pk = await this.db.valueQueryAsync(
              `SELECT key FROM items WHERE itemID = ?`, [parentNoteID]
            );
            obj['parentItem'] = this.toString(pk, '') || false;
          }
        }
      } else if (itemType === 'attachment') {
        let attRows = await this.db.queryAsync(
          `SELECT parentItemID, linkMode, contentType, path, storageHash, storageModTime
           FROM itemAttachments WHERE itemID = ?`,
          [itemID]
        );
        if (attRows.length > 0) {
          let lm = this.toNumber(attRows[0]['linkMode']);
          let linkModeStr = 'imported_file';
          if (lm === 1) { linkModeStr = 'imported_url'; }
          else if (lm === 2) { linkModeStr = 'linked_file'; }
          else if (lm === 3) { linkModeStr = 'linked_url'; }
          else if (lm === 4) { linkModeStr = 'embedded_image'; }
          obj['linkMode'] = linkModeStr;
          obj['contentType'] = this.toString(attRows[0]['contentType'], '');
          obj['path'] = this.toString(attRows[0]['path'], '');
          let parentAttID = this.toNullableNumber(attRows[0]['parentItemID']);
          if (parentAttID !== null) {
            let pk = await this.db.valueQueryAsync(
              `SELECT key FROM items WHERE itemID = ?`, [parentAttID]
            );
            obj['parentItem'] = this.toString(pk, '') || false;
          }
        }
      } else if (itemType === 'annotation') {
        // Query by annotationID (the item's key), NOT by parentItemID.
        // itemAnnotations.annotationID is the annotation item's key.
        let annRows = await this.db.queryAsync(
          `SELECT annotationID, parentItemID, type, pageIndex, x, y, width, height,
                  color, text, comment, authorName, sortIndex, dateModified
           FROM itemAnnotations WHERE annotationID = ?`,
          [itemKey]
        );
        if (annRows.length > 0) {
          let ann = annRows[0];
          obj['annotationType'] = this.toString(ann['type'], 'highlight');
          obj['annotationText'] = this.toString(ann['text'], '');
          obj['annotationComment'] = this.toString(ann['comment'], '');
          obj['annotationColor'] = this.toString(ann['color'], '#FFD700');
          obj['annotationPageLabel'] = `${this.toNumber(ann['pageIndex'])}`;
          obj['annotationSortIndex'] = this.toString(ann['sortIndex'], '');
          obj['annotationPosition'] = JSON.stringify({
            x: this.toFloat(ann['x']), y: this.toFloat(ann['y']),
            width: this.toFloat(ann['width']), height: this.toFloat(ann['height']),
          });
          // Resolve parentItem key
          let parentAnnID = this.toNullableNumber(ann['parentItemID']);
          if (parentAnnID !== null) {
            let pk = await this.db.valueQueryAsync(
              `SELECT key FROM items WHERE itemID = ?`, [parentAnnID]
            );
            obj['parentItem'] = this.toString(pk, '') || false;
          }
        }
        // TODO: when saveAnnotation() creates first-class annotation items
        // in the items table, this path will produce full annotation JSON.
        // Currently, saveAnnotation() still writes via parent attachment,
        // so annotation items may not have an itemAnnotations row.
      }

      // Deleted / trash flag
      let delCount = this.toNumber(await this.db.valueQueryAsync(
        `SELECT COUNT(*) FROM deletedItems WHERE itemID = ?`, [itemID]
      ));
      if (delCount > 0) {
        obj['deleted'] = true;
      }

      results.push(obj);
    }
    return results;
  }

  private async insertStarterItem(title: string, creator: string, itemType: string, date: string, publisher: string, collectionID: number): Promise<void> {
    let typeID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemTypeID FROM itemTypes WHERE typeName = ?`, [itemType]
    ));
    let key = title.toLowerCase().replace(/[^a-z0-9]+/g, '-').substring(0, 32);
    await this.db.executeSql(
      `INSERT OR IGNORE INTO items (itemTypeID, libraryID, key, version, synced)
       VALUES (?, 1, ?, 1, 1)`,
      [typeID > 0 ? typeID : 1, key]
    );
    let itemID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [key]
    ));
    await this.db.executeSql(
      `INSERT OR IGNORE INTO collectionItems (collectionID, itemID) VALUES (?, ?)`,
      [collectionID, itemID]
    );
    await this.putItemField(itemID, 'title', title);
    await this.putItemField(itemID, 'creator', creator);
    await this.putItemField(itemID, 'itemType', itemType);
    await this.putItemField(itemID, 'date', date);
    await this.putItemField(itemID, 'publisher', publisher);
  }

  private async upsertRemoteCollection(key: string, version: number, data: Record<string, Object>, libraryID: number): Promise<void> {
    let name = this.remoteString(data, 'name', 'Untitled Collection');
    let parentKey = this.remoteString(data, 'parentCollection', '');
    let parentID: number | null = null;
    if (parentKey.length > 0 && parentKey !== 'false') {
      parentID = this.toNumber(await this.db.valueQueryAsync(
        `SELECT collectionID FROM collections WHERE libraryID = ? AND key = ?`, [libraryID, parentKey]
      ));
      if (parentID === 0) { parentID = null; }
    }
    if (parentID === null) {
      await this.db.executeSql(
        `INSERT OR REPLACE INTO collections
         (collectionID, collectionName, parentCollectionID, libraryID, key, version, synced)
         VALUES (
           COALESCE((SELECT collectionID FROM collections WHERE libraryID = ? AND key = ?), NULL),
           ?, NULL, ?, ?, ?, 1
         )`,
        [libraryID, key, name, libraryID, key, version]
      );
    } else {
      await this.db.executeSql(
        `INSERT OR REPLACE INTO collections
         (collectionID, collectionName, parentCollectionID, libraryID, key, version, synced)
         VALUES (
           COALESCE((SELECT collectionID FROM collections WHERE libraryID = ? AND key = ?), NULL),
           ?, ?, ?, ?, ?, 1
         )`,
        [libraryID, key, name, parentID, libraryID, key, version]
      );
    }
  }

  private async upsertRemoteSearch(key: string, version: number, data: Record<string, Object>, libraryID: number): Promise<void> {
    let name = this.remoteString(data, 'name', 'Saved Search');
    await this.db.executeSql(
      `INSERT OR REPLACE INTO savedSearches
       (savedSearchID, savedSearchName, libraryID, key, version, synced)
       VALUES (
         COALESCE((SELECT savedSearchID FROM savedSearches WHERE libraryID = ? AND key = ?), NULL),
         ?, ?, ?, ?, 1
       )`,
      [libraryID, key, name, libraryID, key, version]
    );
    let savedSearchID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT savedSearchID FROM savedSearches WHERE libraryID = ? AND key = ?`,
      [libraryID, key]
    ));
    if (savedSearchID === 0) {
      return;
    }
    // Clean old conditions, then re-insert
    await this.db.executeSql(
      `DELETE FROM savedSearchConditions WHERE savedSearchID = ?`, [savedSearchID]
    );
    let conditions = data['conditions'] as Record<string, Object>[] | undefined;
    if (!conditions) {
      return;
    }
    for (let i = 0; i < conditions.length; i++) {
      let cond = conditions[i];
      let condition = this.remoteString(cond, 'condition', '');
      let operator = this.remoteString(cond, 'operator', '');
      let value = this.remoteString(cond, 'value', '');
      let required = this.remoteNumber(cond, 'required', 0);
      if (condition.length === 0) {
        continue;
      }
      await this.db.executeSql(
        `INSERT OR REPLACE INTO savedSearchConditions
         (savedSearchID, searchConditionID, condition, operator, value, required)
         VALUES (?, ?, ?, ?, ?, ?)`,
        [savedSearchID, i + 1, condition, operator, value, required]
      );
    }
  }

  private async upsertRemoteItem(key: string, version: number, data: Record<string, Object>, libraryID: number): Promise<void> {
    // Parse with ItemModel.fromJSON for consistent field extraction
    let item = new ItemModel();
    item.fromJSON(data);

    let itemType = this.remoteString(data, 'itemType', 'journalArticle');
    let typeID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemTypeID FROM itemTypes WHERE typeName = ?`, [itemType]
    ));
    let dateAdded = this.remoteString(data, 'dateAdded', '');
    let dateModified = this.remoteString(data, 'dateModified', '');

    // Upsert items row with proper date handling.
    // Use COALESCE(NULLIF(?, ''), datetime('now')) so that empty-string
    // parameters fall back to the SQL function, not a literal string.
    if (dateAdded.length === 0) {
      await this.db.executeSql(
        `INSERT OR REPLACE INTO items
         (itemID, itemTypeID, libraryID, key, version, synced, dateModified)
         VALUES (
           COALESCE((SELECT itemID FROM items WHERE libraryID = ? AND key = ?), NULL),
           ?, ?, ?, ?, 1, COALESCE(NULLIF(?, ''), datetime('now'))
         )`,
        [libraryID, key, typeID > 0 ? typeID : 1, libraryID, key, version, dateModified]
      );
    } else {
      await this.db.executeSql(
        `INSERT OR REPLACE INTO items
         (itemID, itemTypeID, libraryID, key, version, synced, dateAdded, dateModified)
         VALUES (
           COALESCE((SELECT itemID FROM items WHERE libraryID = ? AND key = ?), NULL),
           ?, ?, ?, ?, 1, ?, COALESCE(NULLIF(?, ''), datetime('now'))
         )`,
        [libraryID, key, typeID > 0 ? typeID : 1, libraryID, key, version,
         dateAdded, dateModified]
      );
    }

    let itemID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = ? AND key = ?`, [libraryID, key]
    ));
    if (itemID === 0) {
      return;
    }

    // itemData: clean old values, then re-insert scalar Zotero item fields
    await this.db.executeSql(`DELETE FROM itemData WHERE itemID = ?`, [itemID]);
    await this.putItemField(itemID, 'itemType', itemType);
    let fieldKeys = Object.keys(data);
    for (let i = 0; i < fieldKeys.length; i++) {
      let fieldName = fieldKeys[i];
      if (this.isScalarItemField(fieldName, data[fieldName])) {
        await this.putItemField(itemID, fieldName, this.remoteValueToString(data[fieldName]));
      }
    }

    // Creators
    await this.upsertRemoteItemCreators(itemID, data, libraryID);

    // Tags
    await this.upsertRemoteItemTags(itemID, data);

    // Collections
    await this.upsertRemoteItemCollections(itemID, data, libraryID);

    // Relations
    await this.upsertRemoteItemRelations(itemID, data, libraryID);

    // Subtype tables
    if (itemType === 'note' || item.isNote()) {
      await this.upsertRemoteNote(itemID, data, libraryID);
    } else if (itemType === 'annotation' || item.isAnnotation()) {
      await this.upsertRemoteAnnotation(itemID, data, libraryID);
    } else if (itemType === 'attachment' || item.isAttachment()) {
      await this.upsertRemoteAttachment(itemID, data, libraryID);
    }
  }

  private async upsertRemoteItemCollections(itemID: number, data: Record<string, Object>, libraryID: number): Promise<void> {
    await this.db.executeSql(`DELETE FROM collectionItems WHERE itemID = ?`, [itemID]);
    let collections = data['collections'] as string[] | undefined;
    if (!collections) { return; }
    for (let i = 0; i < collections.length; i++) {
      let collectionID = this.toNumber(await this.db.valueQueryAsync(
        `SELECT collectionID FROM collections WHERE libraryID = ? AND key = ?`, [libraryID, collections[i]]
      ));
      if (collectionID > 0) {
        await this.db.executeSql(
          `INSERT OR IGNORE INTO collectionItems (collectionID, itemID) VALUES (?, ?)`,
          [collectionID, itemID]
        );
      }
    }
  }

  private async upsertRemoteItemTags(itemID: number, data: Record<string, Object>): Promise<void> {
    let tagObjects = data['tags'] as Record<string, Object>[] | undefined;
    if (!tagObjects) { return; }
    await this.db.executeSql(`DELETE FROM itemTags WHERE itemID = ?`, [itemID]);
    for (let i = 0; i < tagObjects.length; i++) {
      let tag = this.remoteString(tagObjects[i], 'tag', '');
      if (tag.length === 0) { continue; }
      let type = this.remoteNumber(tagObjects[i], 'type', 0);
      await this.db.executeSql(`INSERT OR IGNORE INTO tags (name) VALUES (?)`, [tag]);
      let tagID = this.toNumber(await this.db.valueQueryAsync(
        `SELECT tagID FROM tags WHERE name = ?`, [tag]
      ));
      await this.db.executeSql(
        `INSERT OR REPLACE INTO itemTags (itemID, tagID, type) VALUES (?, ?, ?)`,
        [itemID, tagID, type]
      );
    }
  }

  private async upsertRemoteItemCreators(itemID: number, data: Record<string, Object>, _libraryID: number): Promise<void> {
    let creatorObjects = data['creators'] as Record<string, Object>[] | undefined;
    // Clean old creators
    await this.db.executeSql(`DELETE FROM itemCreators WHERE itemID = ?`, [itemID]);
    if (!creatorObjects || creatorObjects.length === 0) {
      return;
    }
    for (let i = 0; i < creatorObjects.length; i++) {
      let c = creatorObjects[i];
      let creatorType = this.remoteString(c, 'creatorType', 'author');
      let firstName = this.remoteString(c, 'firstName', '');
      let lastName = this.remoteString(c, 'lastName', '');
      let name = this.remoteString(c, 'name', '');
      let fieldMode = 0;
      if (name.length > 0 && lastName.length === 0) {
        lastName = name;
        fieldMode = 1;
      }
      if (lastName.length === 0 && firstName.length === 0 && name.length === 0) {
        continue;
      }
      // Upsert creator
      await this.db.executeSql(
        `INSERT OR IGNORE INTO creators (firstName, lastName, fieldMode) VALUES (?, ?, ?)`,
        [firstName, lastName, fieldMode]
      );
      let creatorID = this.toNumber(await this.db.valueQueryAsync(
        `SELECT creatorID FROM creators WHERE lastName = ? AND firstName = ? AND fieldMode = ?`,
        [lastName, firstName, fieldMode]
      ));
      if (creatorID === 0) {
        continue;
      }
      // Resolve creatorTypeID
      let creatorTypeID = this.toNumber(await this.db.valueQueryAsync(
        `SELECT creatorTypeID FROM creatorTypes WHERE creatorType = ?`, [creatorType]
      ));
      if (creatorTypeID === 0) {
        creatorTypeID = 1; // fallback to 'author'
      }
      await this.db.executeSql(
        `INSERT OR REPLACE INTO itemCreators (itemID, creatorID, creatorTypeID, orderIndex)
         VALUES (?, ?, ?, ?)`,
        [itemID, creatorID, creatorTypeID, i]
      );
    }
  }

  private async upsertRemoteItemRelations(itemID: number, data: Record<string, Object>, libraryID: number): Promise<void> {
    let relationMap = data['relations'] as Record<string, string[]> | undefined;
    if (!relationMap) {
      // No relations field at all — preserve existing relations
      return;
    }
    // Always clean old relations when the field is present (even if empty)
    await this.db.executeSql(`DELETE FROM itemRelations WHERE itemID = ?`, [itemID]);
    let relatedKeys = relationMap['dc:relation'] ?? [];
    if (relatedKeys.length === 0) {
      return;
    }
    for (let i = 0; i < relatedKeys.length; i++) {
      let relatedID = this.toNumber(await this.db.valueQueryAsync(
        `SELECT itemID FROM items WHERE libraryID = ? AND key = ?`,
        [libraryID, relatedKeys[i]]
      ));
      if (relatedID === 0 || relatedID === itemID) {
        continue;
      }
      await this.db.executeSql(
        `INSERT OR IGNORE INTO itemRelations (itemID, relatedItemID) VALUES (?, ?)`,
        [itemID, relatedID]
      );
      await this.db.executeSql(
        `INSERT OR IGNORE INTO itemRelations (itemID, relatedItemID) VALUES (?, ?)`,
        [relatedID, itemID]
      );
    }
  }

  private async _listRelatedItemKeys(itemKey: string): Promise<string[]> {
    let itemID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [itemKey]
    ));
    if (itemID === 0) {
      return [];
    }
    let rows = await this.db.queryAsync(
      `SELECT i.key
       FROM itemRelations r
       JOIN items i ON i.itemID = r.relatedItemID
       WHERE r.itemID = ?
       ORDER BY i.dateModified DESC, i.itemID DESC`,
      [itemID]
    );
    let relatedKeys: string[] = [];
    for (let i = 0; i < rows.length; i++) {
      let key = this.toString(rows[i]['key'], '');
      if (key.length > 0 && relatedKeys.indexOf(key) < 0) {
        relatedKeys.push(key);
      }
    }
    return relatedKeys;
  }

  private async upsertRemoteNote(itemID: number, data: Record<string, Object>, libraryID: number): Promise<void> {
    let note = this.remoteString(data, 'note', '');
    let title = this.remoteString(data, 'title', '');
    // displayTitle: explicit title or first 80 chars of stripped note
    if (title.length === 0 && note.length > 0) {
      let plain = note.replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
      title = plain.length > 80 ? plain.substring(0, 80) : plain;
    }
    let parentKey = this.remoteString(data, 'parentItem', '');
    let parentID = parentKey.length > 0 ? this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = ? AND key = ?`, [libraryID, parentKey]
    )) : 0;
    await this.db.executeSql(
      `INSERT OR REPLACE INTO itemNotes (itemID, parentItemID, note, title)
       VALUES (?, ?, ?, ?)`,
      [itemID, parentID > 0 ? parentID : null, note, title]
    );
  }

  private async upsertRemoteAnnotation(itemID: number, data: Record<string, Object>, libraryID: number): Promise<void> {
    let annotationID = this.remoteString(data, 'key', '');
    if (annotationID.length === 0) {
      return;
    }
    let atype = this.remoteString(data, 'annotationType', 'highlight');
    let pageLabel = this.remoteString(data, 'annotationPageLabel', '0');
    let pageIndex = Number.parseInt(pageLabel, 10);
    if (pageIndex !== pageIndex) { pageIndex = 0; }
    let positionStr = this.remoteString(data, 'annotationPosition', '{}');
    let pos = this.parseAnnotationPosition(positionStr);
    let color = this.remoteString(data, 'annotationColor', '#FFD700');
    let text = this.remoteString(data, 'annotationText', '');
    let comment = this.remoteString(data, 'annotationComment', '');
    let authorName = this.remoteString(data, 'annotationAuthorName', '');
    let sortIndex = this.remoteString(data, 'annotationSortIndex', '');
    let dateModified = this.remoteString(data, 'dateModified', '');

    let parentKey = this.remoteString(data, 'parentItem', '');
    let parentID = parentKey.length > 0 ? this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = ? AND key = ?`, [libraryID, parentKey]
    )) : 0;
    if (parentID === 0) {
      return; // annotation without parent is invalid
    }

    await this.db.executeSql(
      `INSERT OR REPLACE INTO itemAnnotations
       (annotationID, parentItemID, type, pageIndex, x, y, width, height,
        color, text, comment, authorName, sortIndex, dateModified, synced)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1)`,
      [
        annotationID, parentID, atype, pageIndex,
        pos.x, pos.y, pos.width, pos.height,
        color, text, comment, authorName, sortIndex,
        dateModified.length > 0 ? dateModified : '',
      ]
    );
  }

  /** Parse Zotero annotationPosition JSON string → {x,y,width,height}. */
  private parseAnnotationPosition(pos: string): { x: number; y: number; width: number; height: number } {
    let result = { x: 0, y: 0, width: 0, height: 0 };
    if (pos.length === 0) { return result; }
    try {
      // Simple JSON parsing without eval — extract numbers via regex
      let xm = pos.match(/"x"\s*:\s*(-?\d+\.?\d*)/);
      let ym = pos.match(/"y"\s*:\s*(-?\d+\.?\d*)/);
      let wm = pos.match(/"width"\s*:\s*(-?\d+\.?\d*)/);
      let hm = pos.match(/"height"\s*:\s*(-?\d+\.?\d*)/);
      if (xm !== null) { result.x = Number.parseFloat(xm[1]); }
      if (ym !== null) { result.y = Number.parseFloat(ym[1]); }
      if (wm !== null) { result.width = Number.parseFloat(wm[1]); }
      if (hm !== null) { result.height = Number.parseFloat(hm[1]); }
    } catch (_e) { /* keep defaults */ }
    return result;
  }

  private async upsertRemoteAttachment(itemID: number, data: Record<string, Object>, libraryID: number): Promise<void> {
    let linkMode = this.remoteString(data, 'linkMode', '');
    if (linkMode.length === 0) { return; }
    // Map all 5 Zotero link modes
    let lower = linkMode.toLowerCase();
    let mode: number;
    if (lower === 'imported_file')  { mode = 0; }
    else if (lower === 'imported_url')   { mode = 1; }
    else if (lower === 'linked_file')    { mode = 2; }
    else if (lower === 'linked_url')     { mode = 3; }
    else if (lower === 'embedded_image') { mode = 4; }
    else { mode = 0; }

    let parentKey = this.remoteString(data, 'parentItem', '');
    let parentID = parentKey.length > 0 ? this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = ? AND key = ?`, [libraryID, parentKey]
    )) : 0;
    let contentType = this.remoteString(data, 'contentType', '');
    // TODO: charset — the current itemAttachments schema uses charsetID (int),
    // not a text column.  Map charset string → charsetID when a charset lookup
    // table is added to the schema.
    let _charset = this.remoteString(data, 'charset', '');
    let path = this.remoteString(data, 'path', this.remoteString(data, 'url', ''));
    let filename = this.remoteString(data, 'filename', '');
    let md5 = this.remoteString(data, 'md5', '');
    let mtime = this.remoteNumber(data, 'mtime', 0);

    if (parentID > 0) {
      await this.db.executeSql(
        `INSERT OR REPLACE INTO itemAttachments
         (itemID, parentItemID, linkMode, contentType, path, syncState, storageHash, storageModTime)
         VALUES (?, ?, ?, ?, ?, 0, ?, ?)`,
        [itemID, parentID, mode, contentType, path, md5.length > 0 ? md5 : null, mtime > 0 ? mtime : null]
      );
    } else {
      await this.db.executeSql(
        `INSERT OR REPLACE INTO itemAttachments
         (itemID, parentItemID, linkMode, contentType, path, syncState, storageHash, storageModTime)
         VALUES (?, NULL, ?, ?, ?, 0, ?, ?)`,
        [itemID, mode, contentType, path, md5.length > 0 ? md5 : null, mtime > 0 ? mtime : null]
      );
    }

    // Also store filename as itemData title if present
    if (filename.length > 0) {
      await this.putItemField(itemID, 'filename', filename);
      let existingTitle = this.remoteString(data, 'title', '');
      if (existingTitle.length === 0) {
        await this.putItemField(itemID, 'title', filename);
      }
    }
  }

  private async putItemField(itemID: number, fieldName: string, value: string): Promise<void> {
    let fieldID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT fieldID FROM fields WHERE fieldName = ?`, [fieldName]
    ));
    if (fieldID === 0) {
      return;
    }
    await this.db.executeSql(
      `INSERT OR IGNORE INTO itemDataValues (value) VALUES (?)`, [value]
    );
    let valueID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT valueID FROM itemDataValues WHERE value = ?`, [value]
    ));
    await this.db.executeSql(
      `INSERT OR REPLACE INTO itemData (itemID, fieldID, valueID) VALUES (?, ?, ?)`,
      [itemID, fieldID, valueID]
    );
  }

  private async attachTags(items: ItemModel[]): Promise<void> {
    for (let i = 0; i < items.length; i++) {
      let itemID = items[i].id ?? 0;
      let rows = await this.db.queryAsync(
        `SELECT t.name, it.type
         FROM itemTags it
         JOIN tags t ON t.tagID = it.tagID
         WHERE it.itemID = ?
         ORDER BY t.name`,
        [itemID]
      );
      let tags: ZoteroTag[] = [];
      for (let j = 0; j < rows.length; j++) {
        tags.push({
          tag: this.toString(rows[j]['name'], ''),
          type: this.toNumber(rows[j]['type']),
        });
      }
      items[i].tags = tags;
    }
  }

  private async getItemTags(itemKey: string): Promise<ZoteroTag[]> {
    let itemID = this.toNumber(await this.db.valueQueryAsync(
      `SELECT itemID FROM items WHERE libraryID = 1 AND key = ?`, [itemKey]
    ));
    if (itemID === 0) {
      return [];
    }
    let rows = await this.db.queryAsync(
      `SELECT t.name, it.type
       FROM itemTags it
       JOIN tags t ON t.tagID = it.tagID
       WHERE it.itemID = ?
       ORDER BY t.name`,
      [itemID]
    );
    let tags: ZoteroTag[] = [];
    for (let i = 0; i < rows.length; i++) {
      tags.push({
        tag: this.toString(rows[i]['name'], ''),
        type: this.toNumber(rows[i]['type']),
      });
    }
    return tags;
  }

  private async uniqueKey(tableName: string, source: string): Promise<string> {
    let base = this.slug(source);
    if (base.length === 0) {
      base = 'zotero';
    }
    let candidate = base.substring(0, 28);
    let suffix = 0;
    while (await this.keyExists(tableName, candidate)) {
      suffix++;
      candidate = `${base.substring(0, 24)}-${suffix}`;
    }
    return candidate;
  }

  private async keyExists(tableName: string, key: string): Promise<boolean> {
    let count = await this.db.valueQueryAsync(
      `SELECT COUNT(*) FROM ${tableName} WHERE libraryID = 1 AND key = ?`, [key]
    );
    return this.toNumber(count) > 0;
  }

  private slug(value: string): string {
    return value.toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-+|-+$/g, '');
  }

  private appendCollectionChildren(target: CollectionTreeRow[], source: Row[], parentID: number | null, level: number): void {
    for (let i = 0; i < source.length; i++) {
      let rowParent = this.toNullableNumber(source[i]['parentCollectionID']);
      if (rowParent !== parentID) {
        continue;
      }
      let collectionID = this.toNumber(source[i]['collectionID']);
      let rowID = `C${collectionID}`;
      target.push({
        id: rowID,
        type: 'collection',
        name: this.toString(source[i]['collectionName'], 'Untitled Collection'),
        level: level,
        isOpen: level === 1,
        hasChildren: this.hasCollectionChildren(source, collectionID),
        libraryID: this.toNumber(source[i]['libraryID']),
        key: this.toString(source[i]['key'], ''),
        parentRowID: parentID === null ? 'L1' : `C${parentID}`,
      });
      this.appendCollectionChildren(target, source, collectionID, level + 1);
    }
  }

  private hasCollectionChildren(source: Row[], collectionID: number): boolean {
    for (let i = 0; i < source.length; i++) {
      if (this.toNullableNumber(source[i]['parentCollectionID']) === collectionID) {
        return true;
      }
    }
    return false;
  }

  private creatorName(row: Row): string {
    let lastName = this.toString(row['lastName'], '');
    let firstName = this.toString(row['firstName'], '');
    if (lastName.length > 0 && firstName.length > 0) {
      return `${lastName}, ${firstName}`;
    }
    return lastName.length > 0 ? lastName : firstName;
  }

  private remoteData(object: Record<string, Object>): Record<string, Object> {
    let data = object['data'] as Record<string, Object> | undefined;
    return data ?? object;
  }

  private remoteString(object: Record<string, Object>, key: string, fallback: string): string {
    let value = object[key];
    if (value === undefined || value === null || typeof value === 'object') {
      return fallback;
    }
    return `${value}`;
  }

  private remoteNumber(object: Record<string, Object>, key: string, fallback: number): number {
    let value = object[key];
    if (value === undefined || value === null) {
      return fallback;
    }
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      let parsed = Number.parseInt(value, 10);
      return parsed !== parsed ? fallback : parsed;
    }
    return fallback;
  }

  private toAnnotationType(value: string): 'highlight' | 'underline' | 'note' | 'image' | 'ink' {
    if (value === 'underline' || value === 'note' || value === 'image' || value === 'ink') {
      return value;
    }
    return 'highlight';
  }

  private remoteValueToString(value: Object): string {
    if (typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean') {
      return `${value}`;
    }
    return '';
  }

  private isScalarItemField(fieldName: string, value: Object): boolean {
    if (fieldName === 'key' || fieldName === 'version' || fieldName === 'itemType' ||
      fieldName === 'collections' || fieldName === 'creators' || fieldName === 'tags' ||
      fieldName === 'relations' || fieldName === 'parentItem' ||
      fieldName === 'linkMode' || fieldName === 'contentType' || fieldName === 'charset' ||
      fieldName === 'md5' || fieldName === 'syncedHash' ||
      fieldName === 'mtime' || fieldName === 'syncedModificationTime' ||
      fieldName === 'filename' || fieldName === 'path' ||
      fieldName === 'note' || fieldName === 'title' ||
      fieldName === 'annotationType' || fieldName === 'annotationText' ||
      fieldName === 'annotationComment' || fieldName === 'annotationColor' ||
      fieldName === 'annotationPageLabel' || fieldName === 'annotationSortIndex' ||
      fieldName === 'annotationPosition' || fieldName === 'annotationAuthorName' ||
      fieldName === 'dateAdded' || fieldName === 'dateModified' ||
      fieldName === 'synced' || fieldName === 'deleted') {
      return false;
    }
    return typeof value === 'string' || typeof value === 'number' || typeof value === 'boolean';
  }

  private toString(value: string | number | null, fallback: string): string {
    if (value === null || value === undefined) {
      return fallback;
    }
    return `${value}`;
  }

  private toNumber(value: string | number | null): number {
    if (value === null || value === undefined) {
      return 0;
    }
    if (typeof value === 'number') {
      return value;
    }
    let parsed = Number.parseInt(value, 10);
    return parsed !== parsed ? 0 : parsed;
  }

  private toFloat(value: string | number | null): number {
    if (value === null || value === undefined) {
      return 0;
    }
    if (typeof value === 'number') {
      return value;
    }
    let parsed = Number.parseFloat(value);
    return parsed !== parsed ? 0 : parsed;
  }

  private toNullableNumber(value: string | number | null): number | null {
    if (value === null || value === undefined || value === '') {
      return null;
    }
    let parsed = this.toNumber(value);
    return parsed === 0 ? null : parsed;
  }

  private fileNameFromUri(uri: string): string {
    let cleaned = uri.split('?')[0];
    let segments = cleaned.split('/');
    let last = segments[segments.length - 1] ?? '';
    if (last.length === 0) {
      return 'Imported File';
    }
    try {
      return decodeURIComponent(last);
    } catch (_err) {
      return last;
    }
  }

  private guessContentType(fileName: string): string {
    let ext = fileName.toLowerCase().split('.').pop() ?? '';
    if (ext === 'pdf') { return 'application/pdf'; }
    if (ext === 'html' || ext === 'htm') { return 'text/html'; }
    if (ext === 'txt' || ext === 'md') { return 'text/plain'; }
    if (ext === 'jpg' || ext === 'jpeg') { return 'image/jpeg'; }
    if (ext === 'png') { return 'image/png'; }
    if (ext === 'gif') { return 'image/gif'; }
    if (ext === 'svg') { return 'image/svg+xml'; }
    return 'application/octet-stream';
  }

  private linkModeName(linkMode: number): string {
    if (linkMode === 0) { return 'imported_file'; }
    if (linkMode === 1) { return 'imported_url'; }
    if (linkMode === 3) { return 'linked_url'; }
    return 'linked_file';
  }
}
