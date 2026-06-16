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
export const SCHEMA_VERSION = 3;

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
  // Creator type enumeration (maps string→ID for itemCreators.creatorTypeID)
  `CREATE TABLE IF NOT EXISTS creatorTypes (
    creatorTypeID INTEGER PRIMARY KEY,
    creatorType TEXT NOT NULL UNIQUE
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
  // Sync queue — persistent local-change queue for upload
  `CREATE TABLE IF NOT EXISTS syncQueue (
    libraryID INT NOT NULL,
    objectType TEXT NOT NULL,
    key TEXT NOT NULL,
    operation TEXT NOT NULL DEFAULT 'upsert',
    tries INT NOT NULL DEFAULT 0,
    lastTryTimestamp INT NOT NULL DEFAULT 0,
    dateAdded TEXT NOT NULL DEFAULT (datetime('now')),
    dateModified TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (libraryID, objectType, key, operation),
    FOREIGN KEY (libraryID) REFERENCES libraries(libraryID) ON DELETE CASCADE
  )`,
  // Sync delete log — persistent deletion tracking for upload
  `CREATE TABLE IF NOT EXISTS syncDeleteLog (
    libraryID INT NOT NULL,
    objectType TEXT NOT NULL,
    key TEXT NOT NULL,
    dateDeleted TEXT NOT NULL DEFAULT (datetime('now')),
    PRIMARY KEY (libraryID, objectType, key),
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
 * Also handles schema migration from older versions.
 */
export async function migrate(db: ZoteroDb): Promise<void> {
  // Phase 1: always run idempotent DDL first.
  // This ensures all tables exist before any migration patch touches them.
  for (let i = 0; i < CORE_TABLES.length; i++) {
    await db.executeSql(CORE_TABLES[i]);
  }

  // Phase 2: detect version and apply schema patches.
  let currentVersion = await detectSchemaVersion(db);

  if (currentVersion < 2) {
    // v1 → v2: add creatorTypes table + itemCreators.creatorTypeID column.
    await db.executeSql(
      `CREATE TABLE IF NOT EXISTS creatorTypes (
        creatorTypeID INTEGER PRIMARY KEY,
        creatorType TEXT NOT NULL UNIQUE
      )`
    );
    if (!(await columnExists(db, 'itemCreators', 'creatorTypeID'))) {
      await db.executeSql(
        `ALTER TABLE itemCreators ADD COLUMN creatorTypeID INT NOT NULL DEFAULT 1`
      );
    }
  }

  if (currentVersion < 3) {
    // v2 → v3: add syncQueue + syncDeleteLog tables.
    // CORE_TABLES already created them for fresh DBs; idempotent for upgrades.
    await db.executeSql(
      `CREATE TABLE IF NOT EXISTS syncQueue (
        libraryID INT NOT NULL,
        objectType TEXT NOT NULL,
        key TEXT NOT NULL,
        operation TEXT NOT NULL DEFAULT 'upsert',
        tries INT NOT NULL DEFAULT 0,
        lastTryTimestamp INT NOT NULL DEFAULT 0,
        dateAdded TEXT NOT NULL DEFAULT (datetime('now')),
        dateModified TEXT NOT NULL DEFAULT (datetime('now')),
        PRIMARY KEY (libraryID, objectType, key, operation)
      )`
    );
    await db.executeSql(
      `CREATE TABLE IF NOT EXISTS syncDeleteLog (
        libraryID INT NOT NULL,
        objectType TEXT NOT NULL,
        key TEXT NOT NULL,
        dateDeleted TEXT NOT NULL DEFAULT (datetime('now')),
        PRIMARY KEY (libraryID, objectType, key)
      )`
    );
  }

  // Phase 3: seed metadata (idempotent INSERT OR IGNORE).
  await seedCoreMetadata(db);

  // Phase 4: record schema version.
  await db.executeSql(
    `INSERT OR REPLACE INTO version (schema, version) VALUES ('zotero', ${SCHEMA_VERSION})`
  );
}

/** Read the current schema version from the version table. */
async function detectSchemaVersion(db: ZoteroDb): Promise<number> {
  try {
    let v = await db.valueQueryAsync(
      `SELECT version FROM version WHERE schema = 'zotero'`
    );
    if (v === null || v === undefined) { return 0; }
    return typeof v === 'number' ? v : Number.parseInt(`${v}`, 10) || 0;
  } catch (_e) {
    return 0;
  }
}

/** Check whether a column exists in a table using PRAGMA table_info. */
async function columnExists(db: ZoteroDb, tableName: string, columnName: string): Promise<boolean> {
  try {
    let rows = await db.queryAsync(`PRAGMA table_info(${tableName})`);
    for (let i = 0; i < rows.length; i++) {
      if (rows[i]['name'] === columnName) { return true; }
    }
    return false;
  } catch (_e) {
    return false;
  }
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

  let creatorTypes: string[] = [
    'author', 'contributor', 'editor', 'translator', 'seriesEditor',
    'interviewee', 'interviewer', 'director', 'scriptwriter', 'producer',
    'castMember', 'sponsor', 'counsel', 'inventor', 'attorneyAgent',
    'recipient', 'performer', 'composer', 'wordsBy', 'cartographer',
    'programmer', 'artist', 'podcaster', 'guest', 'presenter',
    'reviewedAuthor',
  ];
  for (let k = 0; k < creatorTypes.length; k++) {
    await db.executeSql(
      `INSERT OR IGNORE INTO creatorTypes (creatorTypeID, creatorType) VALUES (?, ?)`,
      [k + 1, creatorTypes[k]]
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
