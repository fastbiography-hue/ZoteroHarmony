/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ported from Zotero Desktop (AGPL-3.0)
 * Original: chrome/content/zotero/xpcom/schema.js  version update steps
 *
 * ***** END LICENSE BLOCK *****
 */

import { ZoteroDb } from './ZoteroDb.ets';

/**
 * Core Zotero SQLite schema — CREATE TABLE statements.
 * Ref: schema.js:2783-3077  per-step DDL
 */
export const SCHEMA_VERSION = 1;

export const CORE_TABLES: string[] = [
  // Ref: schema.js:2783
  `CREATE TABLE IF NOT EXISTS libraries (
    libraryID INTEGER PRIMARY KEY,
    type TEXT NOT NULL,
    editable INT NOT NULL DEFAULT 1,
    filesEditable INT NOT NULL DEFAULT 1,
    version INT NOT NULL DEFAULT 0,
    lastSync INT NOT NULL DEFAULT 0,
    lastStorageSync INT NOT NULL DEFAULT 0
  )`,
  // Ref: schema.js:2941
  `CREATE TABLE IF NOT EXISTS collections (
    collectionID INTEGER PRIMARY KEY,
    collectionName TEXT NOT NULL,
    parentCollectionID INT DEFAULT NULL,
    clientDateModified TEXT NOT NULL DEFAULT (datetime('now')),
    libraryID INT NOT NULL,
    key TEXT NOT NULL,
    version INT NOT NULL DEFAULT 0,
    synced INT NOT NULL DEFAULT 0,
    UNIQUE (libraryID, key),
    FOREIGN KEY (libraryID) REFERENCES libraries(libraryID) ON DELETE CASCADE,
    FOREIGN KEY (parentCollectionID) REFERENCES collections(collectionID) ON DELETE CASCADE
  )`,
  // Ref: schema.js:2946
  `CREATE TABLE IF NOT EXISTS items (
    itemID INTEGER PRIMARY KEY,
    itemTypeID INT NOT NULL,
    dateAdded TEXT NOT NULL DEFAULT (datetime('now')),
    dateModified TEXT NOT NULL DEFAULT (datetime('now')),
    clientDateModified TEXT NOT NULL DEFAULT (datetime('now')),
    libraryID INT NOT NULL,
    key TEXT NOT NULL,
    version INT NOT NULL DEFAULT 0,
    synced INT NOT NULL DEFAULT 0,
    UNIQUE (libraryID, key),
    FOREIGN KEY (libraryID) REFERENCES libraries(libraryID) ON DELETE CASCADE
  )`,
  `CREATE TABLE IF NOT EXISTS itemTypes (
    itemTypeID INTEGER PRIMARY KEY,
    typeName TEXT NOT NULL UNIQUE
  )`,
  `CREATE TABLE IF NOT EXISTS fields (
    fieldID INTEGER PRIMARY KEY,
    fieldName TEXT NOT NULL UNIQUE
  )`,
  `CREATE TABLE IF NOT EXISTS itemDataValues (
    valueID INTEGER PRIMARY KEY,
    value TEXT NOT NULL UNIQUE
  )`,
  // Ref: schema.js:2957
  `CREATE TABLE IF NOT EXISTS creators (
    creatorID INTEGER PRIMARY KEY,
    firstName TEXT,
    lastName TEXT,
    fieldMode INT DEFAULT 0,
    UNIQUE (lastName, firstName, fieldMode)
  )`,
  // Ref: schema.js:2960
  `CREATE TABLE IF NOT EXISTS itemCreators (
    itemID INT NOT NULL,
    creatorID INT NOT NULL,
    creatorTypeID INT NOT NULL DEFAULT 1,
    orderIndex INT NOT NULL DEFAULT 0,
    PRIMARY KEY (itemID, creatorID, creatorTypeID, orderIndex),
    FOREIGN KEY (itemID) REFERENCES items(itemID) ON DELETE CASCADE,
    FOREIGN KEY (creatorID) REFERENCES creators(creatorID) ON DELETE CASCADE
  )`,
  // Ref: schema.js:2965
  `CREATE TABLE IF NOT EXISTS savedSearches (
    savedSearchID INTEGER PRIMARY KEY,
    savedSearchName TEXT NOT NULL,
    clientDateModified TEXT NOT NULL DEFAULT (datetime('now')),
    libraryID INT NOT NULL,
    key TEXT NOT NULL,
    version INT NOT NULL DEFAULT 0,
    synced INT NOT NULL DEFAULT 0,
    UNIQUE (libraryID, key),
    FOREIGN KEY (libraryID) REFERENCES libraries(libraryID) ON DELETE CASCADE
  )`,
  // Ref: schema.js:2970
  `CREATE TABLE IF NOT EXISTS tags (
    tagID INTEGER PRIMARY KEY,
    name TEXT NOT NULL UNIQUE
  )`,
  // Ref: schema.js:2973
  `CREATE TABLE IF NOT EXISTS itemTags (
    itemID INT NOT NULL,
    tagID INT NOT NULL,
    type INT NOT NULL DEFAULT 0,
    PRIMARY KEY (itemID, tagID),
    FOREIGN KEY (itemID) REFERENCES items(itemID) ON DELETE CASCADE,
    FOREIGN KEY (tagID) REFERENCES tags(tagID) ON DELETE CASCADE
  )`,
  // Ref: schema.js:2985
  `CREATE TABLE IF NOT EXISTS itemData (
    itemID INT NOT NULL,
    fieldID INT NOT NULL,
    valueID INT,
    PRIMARY KEY (itemID, fieldID),
    FOREIGN KEY (itemID) REFERENCES items(itemID) ON DELETE CASCADE
  )`,
  // Ref: schema.js:2991
  `CREATE TABLE IF NOT EXISTS itemNotes (
    itemID INTEGER PRIMARY KEY,
    parentItemID INT,
    note TEXT,
    title TEXT,
    FOREIGN KEY (itemID) REFERENCES items(itemID) ON DELETE CASCADE,
    FOREIGN KEY (parentItemID) REFERENCES items(itemID) ON DELETE CASCADE
  )`,
  // Ref: schema.js:3000
  `CREATE TABLE IF NOT EXISTS itemAttachments (
    itemID INTEGER PRIMARY KEY,
    parentItemID INT,
    linkMode INT DEFAULT 0,
    contentType TEXT,
    charsetID INT,
    path TEXT,
    syncState INT DEFAULT 0,
    storageModTime INT,
    storageHash TEXT,
    FOREIGN KEY (itemID) REFERENCES items(itemID) ON DELETE CASCADE,
    FOREIGN KEY (parentItemID) REFERENCES items(itemID) ON DELETE CASCADE
  )`,
  `CREATE TABLE IF NOT EXISTS itemAnnotations (
    annotationID TEXT PRIMARY KEY,
    parentItemID INT NOT NULL,
    type TEXT NOT NULL,
    pageIndex INT NOT NULL DEFAULT 0,
    x REAL NOT NULL DEFAULT 0,
    y REAL NOT NULL DEFAULT 0,
    width REAL NOT NULL DEFAULT 0,
    height REAL NOT NULL DEFAULT 0,
    color TEXT NOT NULL DEFAULT '#FFD700',
    text TEXT NOT NULL DEFAULT '',
    comment TEXT NOT NULL DEFAULT '',
    authorName TEXT NOT NULL DEFAULT '',
    sortIndex TEXT NOT NULL DEFAULT '',
    dateModified TEXT NOT NULL DEFAULT (datetime('now')),
    synced INT NOT NULL DEFAULT 0,
    FOREIGN KEY (parentItemID) REFERENCES items(itemID) ON DELETE CASCADE
  )`,
  `CREATE TABLE IF NOT EXISTS itemRelations (
    itemID INT NOT NULL,
    relatedItemID INT NOT NULL,
    PRIMARY KEY (itemID, relatedItemID),
    FOREIGN KEY (itemID) REFERENCES items(itemID) ON DELETE CASCADE,
    FOREIGN KEY (relatedItemID) REFERENCES items(itemID) ON DELETE CASCADE
  )`,
  // Ref: schema.js:3011
  `CREATE TABLE IF NOT EXISTS collectionItems (
    collectionID INT NOT NULL,
    itemID INT NOT NULL,
    orderIndex INT NOT NULL DEFAULT 0,
    PRIMARY KEY (collectionID, itemID),
    FOREIGN KEY (collectionID) REFERENCES collections(collectionID) ON DELETE CASCADE,
    FOREIGN KEY (itemID) REFERENCES items(itemID) ON DELETE CASCADE
  )`,
  // Ref: schema.js:3030
  `CREATE TABLE IF NOT EXISTS groups (
    groupID INTEGER PRIMARY KEY,
    libraryID INT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    version INT NOT NULL DEFAULT 0,
    FOREIGN KEY (libraryID) REFERENCES libraries(libraryID) ON DELETE CASCADE
  )`,
  // Ref: schema.js:3022
  `CREATE TABLE IF NOT EXISTS deletedItems (
    itemID INTEGER PRIMARY KEY,
    dateDeleted TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (itemID) REFERENCES items(itemID) ON DELETE CASCADE
  )`,
  // Ref: schema.js:3017
  `CREATE TABLE IF NOT EXISTS savedSearchConditions (
    savedSearchID INT NOT NULL,
    searchConditionID INT NOT NULL,
    condition TEXT NOT NULL,
    operator TEXT,
    value TEXT,
    required INT,
    PRIMARY KEY (savedSearchID, searchConditionID),
    FOREIGN KEY (savedSearchID) REFERENCES savedSearches(savedSearchID) ON DELETE CASCADE
  )`,
  // Sync metadata table
  `CREATE TABLE IF NOT EXISTS syncedSettings (
    setting TEXT NOT NULL,
    libraryID INT NOT NULL,
    value NOT NULL,
    version INT NOT NULL DEFAULT 0,
    synced INT NOT NULL DEFAULT 0,
    PRIMARY KEY (setting, libraryID),
    FOREIGN KEY (libraryID) REFERENCES libraries(libraryID) ON DELETE CASCADE
  )`,
  // Version tracker
  `CREATE TABLE IF NOT EXISTS version (
    schema TEXT PRIMARY KEY,
    version INT NOT NULL
  )`,
];

/**
 * Run all CREATE TABLE statements against the DB.
 */
/**
 * Run all CREATE TABLE statements against the DB.
 * Accepts a DB wrapper with executeSql(sql: string): Promise<void>.
 */
export async function migrate(db: ZoteroDb): Promise<void> {
  for (let i = 0; i < CORE_TABLES.length; i++) {
    await db.executeSql(CORE_TABLES[i]);
  }
  await seedCoreMetadata(db);
  // Record schema version
  await db.executeSql(
    `INSERT OR REPLACE INTO version (schema, version) VALUES ('zotero', ${SCHEMA_VERSION})`
  );
}

async function seedCoreMetadata(db: ZoteroDb): Promise<void> {
  let itemTypes: string[] = [
    'journalArticle', 'book', 'bookSection', 'conferencePaper', 'thesis',
    'report', 'webpage', 'note', 'attachment', 'annotation',
  ];
  for (let i = 0; i < itemTypes.length; i++) {
    await db.executeSql(
      `INSERT OR IGNORE INTO itemTypes (itemTypeID, typeName) VALUES (?, ?)`,
      [i + 1, itemTypes[i]]
    );
  }

  let fields: string[] = [
    'title', 'abstractNote', 'date', 'DOI', 'ISBN', 'ISSN', 'url',
    'accessDate', 'archive', 'archiveLocation', 'libraryCatalog',
    'callNumber', 'rights', 'extra', 'pages', 'volume', 'issue',
    'series', 'seriesNumber', 'seriesTitle', 'journalAbbreviation',
    'language', 'shortTitle', 'publicationTitle', 'publisher', 'place',
    'edition', 'numberOfVolumes', 'number', 'section', 'court',
    'reporter', 'reporterVolume', 'citationKey', 'creator', 'itemType',
    'note',
  ];
  for (let j = 0; j < fields.length; j++) {
    await db.executeSql(
      `INSERT OR IGNORE INTO fields (fieldID, fieldName) VALUES (?, ?)`,
      [j + 1, fields[j]]
    );
  }
}
