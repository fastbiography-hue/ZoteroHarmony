/*
 * Type definitions for Item model — Zotero Web API v3 structures.
 * Extracted from ItemModel.ets to keep each file under 200 lines.
 * Ref: chrome/content/zotero/xpcom/data/item.js
 */

import { DataObjectJSON } from './DataObject.ets';

// ==================================================================
// Creator & Tag
// ==================================================================

/**
 * Creator attached to an item.
 * Ref: item.js:55-57 _creators / getCreatorsJSON()
 */
export interface ZoteroCreator {
  creatorType: string;    // e.g. 'author', 'editor', 'translator'
  firstName: string;
  lastName: string;
  fieldMode: number;      // 0 = two-field (first/last), 1 = single-field
}

/**
 * Tag attached to an item.
 * Ref: item.js:81 _tags; item.js:5823-5827
 */
export interface ZoteroTag {
  tag: string;
  type: number;           // 0 = standard, 1 = automatic
}

// ==================================================================
// Enums
// ==================================================================

/**
 * Attachment link mode.
 * Ref: item.js:46 _attachmentLinkMode
 */
export enum AttachmentLinkMode {
  IMPORTED_FILE  = 0,
  IMPORTED_URL   = 1,
  LINKED_FILE    = 2,
  LINKED_URL     = 3,
  EMBEDDED_IMAGE = 4,
}

/**
 * Annotation type.
 * Ref: item.js:70 _annotationType
 */
export enum AnnotationTypeEnum {
  HIGHLIGHT  = 'highlight',
  UNDERLINE  = 'underline',
  NOTE       = 'note',
  IMAGE      = 'image',
  INK        = 'ink',
  TEXT       = 'text',
}

// ==================================================================
// Item JSON — Zotero Web API v3
// ==================================================================

/**
 * Complete Item JSON matching Zotero Web API v3 structure.
 * Ref: item.js:5725-5867 (toJSON)
 */
export interface ItemJSON extends DataObjectJSON {
  itemType: string;
  creators?: ZoteroCreator[];
  tags?: ZoteroTag[];
  collections?: string[];
  relations?: Record<string, string[]>;
  parentItem?: string | boolean;
  linkMode?: string;
  contentType?: string;
  charset?: string;
  path?: string;
  filename?: string;
  note?: string;
  annotationType?: string;
  annotationAuthorName?: string;
  annotationText?: string;
  annotationComment?: string;
  annotationColor?: string;
  annotationPageLabel?: string;
  annotationSortIndex?: string;
  annotationPosition?: string;
  dateAdded?: string;
  dateModified?: string;
  accessDate?: string;
  /** Dynamic field values from itemData (title, DOI, etc.). */
  extraFields?: Record<string, string>;
}

// ==================================================================
// ItemType & CSLField enums (moved from ItemFieldsMeta to break cycle)
// ==================================================================

export enum ItemType {
  JOURNAL_ARTICLE = 'journalArticle', BOOK = 'book', BOOK_SECTION = 'bookSection',
  CONFERENCE_PAPER = 'conferencePaper', THESIS = 'thesis', REPORT = 'report',
  WEBPAGE = 'webpage', NOTE = 'note', ATTACHMENT = 'attachment',
  ANNOTATION = 'annotation', ARTWORK = 'artwork', AUDIO_RECORDING = 'audioRecording',
  BILL = 'bill', BLOG_POST = 'blogPost', CASE = 'case',
  COMPUTER_PROGRAM = 'computerProgram', DICTIONARY_ENTRY = 'dictionaryEntry',
  DOCUMENT = 'document', EMAIL = 'email', ENCYCLOPEDIA_ARTICLE = 'encyclopediaArticle',
  FILM = 'film', FORUM_POST = 'forumPost', HEARING = 'hearing',
  INSTANT_MESSAGE = 'instantMessage', INTERVIEW = 'interview', LETTER = 'letter',
  MAGAZINE_ARTICLE = 'magazineArticle', MANUSCRIPT = 'manuscript', MAP = 'map',
  NEWSPAPER_ARTICLE = 'newspaperArticle', PATENT = 'patent', PODCAST = 'podcast',
  PREPRINT = 'preprint', PRESENTATION = 'presentation', RADIO_BROADCAST = 'radioBroadcast',
  SOFTWARE = 'software', STATUTE = 'statute', TV_BROADCAST = 'tvBroadcast',
  VIDEO_RECORDING = 'videoRecording',
}

export enum CSLField {
  TITLE = 'title', ABSTRACT = 'abstractNote', DATE = 'date', DOI = 'DOI',
  ISBN = 'ISBN', ISSN = 'ISSN', URL = 'url', ACCESS_DATE = 'accessDate',
  ARCHIVE = 'archive', ARCHIVE_LOCATION = 'archiveLocation', LIBRARY_CATALOG = 'libraryCatalog',
  CALL_NUMBER = 'callNumber', RIGHTS = 'rights', EXTRA = 'extra', PAGES = 'pages',
  VOLUME = 'volume', ISSUE = 'issue', SERIES = 'series', SERIES_NUMBER = 'seriesNumber',
  SERIES_TITLE = 'seriesTitle', JOURNAL_ABBREVIATION = 'journalAbbreviation',
  LANGUAGE = 'language', SHORT_TITLE = 'shortTitle', PUBLICATION_TITLE = 'publicationTitle',
  PUBLISHER = 'publisher', PLACE = 'place', EDITION = 'edition',
  NUMBER_OF_VOLUMES = 'numberOfVolumes', NUMBER = 'number', SECTION = 'section',
  COURT = 'court', REPORTER = 'reporter', REPORTER_VOLUME = 'reporterVolume',
  CITATION_KEY = 'citationKey', CREATOR = 'creator', ITEM_TYPE = 'itemType', NOTE = 'note',
}
