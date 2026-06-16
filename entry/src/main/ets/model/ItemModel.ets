/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ported from Zotero Desktop (AGPL-3.0)
 * Original: chrome/content/zotero/xpcom/data/item.js
 *
 * ***** END LICENSE BLOCK *****
 */

import { DataObject, JSONMode } from './DataObject.ets';
import {
  ZoteroCreator, ZoteroTag, ItemJSON,
  AttachmentLinkMode, AnnotationTypeEnum
} from './ItemTypes.ets';

/**
 * Core Item entity. Covers four subtypes:
 *   - Regular Item  (journalArticle, book, …)
 *   - Attachment    (imported/linked file, URL)
 *   - Note          (rich-text HTML)
 *   - Annotation    (PDF annotation)
 *
 * Ref: item.js:30-95  constructor fields
 */
export class ItemModel extends DataObject {
  // ---- Type (ref: item.js:40) ----
  private _itemTypeID: number | null = null;
  /** Zotero API itemType string (e.g. 'journalArticle', 'book', 'note', 'attachment').
   *  Set by fromJSON.  Used by isRegularItem() when _itemTypeID is not available. */
  private _itemTypeName: string | null = null;

  // ---- Creators (ref: item.js:55-57) ----
  private _creators: ZoteroCreator[] = [];

  // ---- Field data — fieldName → value (ref: item.js:60) ----
  private _itemData: Map<string, string> = new Map();

  // ---- Note (ref: item.js:61-62) ----
  private _noteText: string | null = null;
  private _displayTitle: string | null = null;

  // ---- Attachment (ref: item.js:45-53) ----
  private _attachmentLinkMode: AttachmentLinkMode | null = null;
  private _attachmentPath: string | null = null;
  private _attachmentContentType: string | null = null;
  private _attachmentCharset: string | null = null;
  private _attachmentSyncedHash: string | null = null;
  private _attachmentSyncedModificationTime: number | null = null;

  // ---- Annotation (ref: item.js:70-79) ----
  private _annotationType: AnnotationTypeEnum | null = null;
  private _annotationAuthorName: string | null = null;
  private _annotationText: string | null = null;
  private _annotationComment: string | null = null;
  private _annotationColor: string | null = null;
  private _annotationPageLabel: string | null = null;
  private _annotationSortIndex: string | null = null;
  private _annotationPosition: string | null = null;

  // ---- Tags & Collections (ref: item.js:81-82) ----
  private _tags: ZoteroTag[] = [];
  private _collectionKeys: string[] = [];

  // ---- Display (ref: item.js:43-44,63) ----
  private _firstCreator: string | null = null;

  protected _objectType = 'item';

  // ==================================================================
  // Public getters
  // ==================================================================

  get itemTypeID(): number | null { return this._itemTypeID; }
  set itemTypeID(value: number | null) { this._itemTypeID = value; }
  get itemTypeName(): string | null { return this._itemTypeName; }
  set itemTypeName(value: string | null) { this._itemTypeName = value; }
  get itemData(): Map<string, string> { return this._itemData; }
  get creators(): ZoteroCreator[] { return this._creators; }
  get noteText(): string | null { return this._noteText; }
  set noteText(value: string | null) { this._noteText = value; }
  get displayTitle(): string | null { return this._displayTitle; }
  set displayTitle(value: string | null) { this._displayTitle = value; }
  get attachmentLinkMode(): AttachmentLinkMode | null { return this._attachmentLinkMode; }
  set attachmentLinkMode(value: AttachmentLinkMode | null) { this._attachmentLinkMode = value; }
  get attachmentPath(): string | null { return this._attachmentPath; }
  set attachmentPath(value: string | null) { this._attachmentPath = value; }
  get attachmentContentType(): string | null { return this._attachmentContentType; }
  set attachmentContentType(value: string | null) { this._attachmentContentType = value; }
  get attachmentCharset(): string | null { return this._attachmentCharset; }
  set attachmentCharset(value: string | null) { this._attachmentCharset = value; }
  get attachmentSyncedHash(): string | null { return this._attachmentSyncedHash; }
  set attachmentSyncedHash(value: string | null) { this._attachmentSyncedHash = value; }
  get attachmentSyncedModificationTime(): number | null { return this._attachmentSyncedModificationTime; }
  set attachmentSyncedModificationTime(value: number | null) { this._attachmentSyncedModificationTime = value; }
  get annotationType(): AnnotationTypeEnum | null { return this._annotationType; }
  get annotationAuthorName(): string | null { return this._annotationAuthorName; }
  set annotationAuthorName(value: string | null) { this._annotationAuthorName = value; }
  get annotationComment(): string | null { return this._annotationComment; }
  set annotationComment(value: string | null) { this._annotationComment = value; }
  get annotationText(): string | null { return this._annotationText; }
  set annotationText(value: string | null) { this._annotationText = value; }
  get annotationColor(): string | null { return this._annotationColor; }
  set annotationColor(value: string | null) { this._annotationColor = value; }
  get annotationPageLabel(): string | null { return this._annotationPageLabel; }
  set annotationPageLabel(value: string | null) { this._annotationPageLabel = value; }
  get annotationSortIndex(): string | null { return this._annotationSortIndex; }
  set annotationSortIndex(value: string | null) { this._annotationSortIndex = value; }
  get annotationPosition(): string | null { return this._annotationPosition; }
  set annotationPosition(value: string | null) { this._annotationPosition = value; }
  get tags(): ZoteroTag[] { return this._tags; }
  set tags(value: ZoteroTag[]) { this._tags = value; }
  get collectionKeys(): string[] { return this._collectionKeys; }

  // ==================================================================
  // Convenience checks (ref: item.js isRegularItem / …)
  // ==================================================================

  isRegularItem(): boolean {
    // DB-backed item: check integer ID
    if (this._itemTypeID !== null) {
      return true;
    }
    // API-deserialized item (no DB ID): check itemTypeName against special types
    if (this._itemTypeName === null || this._itemTypeName.length === 0) {
      return false;
    }
    let lower = this._itemTypeName.toLowerCase();
    return lower !== 'note' && lower !== 'attachment' && lower !== 'annotation';
  }

  isNote(): boolean {
    return this._noteText !== null;
  }

  isAttachment(): boolean {
    return this._attachmentLinkMode !== null;
  }

  isAnnotation(): boolean {
    return this._annotationType !== null;
  }

  // ==================================================================
  // toJSON — Zotero Web API v3 (ref: item.js:5725-5867)
  // ==================================================================

  toJSON(mode: JSONMode = 'new'): ItemJSON {
    let obj: ItemJSON = {
      key: this.key,
      version: this.version,
      itemType: this._itemTypeName ?? this.itemData.get('itemType') ?? '',
    };

    // Fields from _itemData (ref: item.js:5737-5742)
    let extra: Record<string, string> = {};
    this._itemData.forEach((value: string, key: string) => {
      if (value !== '' || mode === 'full') { extra[key] = value; }
    });
    obj.extraFields = extra;

    // Creators or parentItem (ref: item.js:5744-5752)
    if (this.isRegularItem()) {
      obj.creators = this._creators.slice();
    } else {
      let pk = this.parentKey;
      if (pk || mode === 'full') {
        obj.parentItem = pk ?? false;
      }
    }

    // Attachment (ref: item.js:5755-5796)
    if (this.isAttachment() && this._attachmentLinkMode !== null) {
      obj.linkMode = AttachmentLinkMode[this._attachmentLinkMode].toLowerCase();
      obj.contentType = this._attachmentContentType ?? undefined;
      if (this._attachmentLinkMode === AttachmentLinkMode.LINKED_FILE) {
        obj.path = this._attachmentPath ?? undefined;
      }
    }

    // Note (ref: item.js:5799-5804)
    if (this.isNote() && this._noteText) {
      obj.note = this._noteText;
    }

    // Annotation (ref: item.js:5806-5818)
    if (this.isAnnotation()) {
      let at = this._annotationType;
      obj.annotationType = at ?? undefined;
      obj.annotationAuthorName = this._annotationAuthorName ?? '';
      obj.annotationComment = this._annotationComment ?? '';
      obj.annotationColor = this._annotationColor ?? '';
      obj.annotationPageLabel = this._annotationPageLabel ?? '';
      obj.annotationSortIndex = this._annotationSortIndex ?? '';
      obj.annotationPosition = this._annotationPosition ?? '';
      if (at === AnnotationTypeEnum.HIGHLIGHT ||
          at === AnnotationTypeEnum.UNDERLINE) {
        obj.annotationText = this._annotationText ?? '';
      }
    }

    // Tags (ref: item.js:5822-5827)
    obj.tags = this._tags.slice();

    // Relations (ref: item.js:5840-5842)
    let rels = this.getRelations();
    if (Object.keys(rels).length > 0) {
      obj.relations = rels;
    }

    return obj;
  }

  /**
   * Populate from Zotero Web API v3 JSON (wrapped or unwrapped).
   *
   * Covers:
   *   Regular items  — key, version, itemType, all common CSL fields,
   *                    creators, tags, collections, relations, parentItem
   *   Attachments    — linkMode, contentType, charset, path, filename
   *   Notes          — note, title (→ displayTitle)
   *   Annotations    — annotationType, annotationText, annotationColor, …
   *
   * Ref: item.js:5373-5416  loadFromObject
   * Ref: item.js:5418-5435  _parseCreators
   * Ref: item.js:5324-5361  _parseTags
   */
  fromJSON(json: Record<string, Object>): void {
    // 1. Unwrap data envelope (Zotero API wraps items in { data: {...} })
    let data = json['data'] as Record<string, Object> | undefined;
    let src: Record<string, Object> = data ?? json;

    // 2. Primary identifiers (ref: item.js:5380-5382)
    let k = this._str(src, 'key');
    if (k !== null) { this.key = k; }
    let v = this._num(src, 'version');
    if (v !== null) { this.version = v; }
    let da = this._str(src, 'dateAdded');
    if (da !== null) { this.dateAdded = da; }
    let dm = this._str(src, 'dateModified');
    if (dm !== null) { this.dateModified = dm; }

    // 3. Item type — store in _itemTypeName (primary) and itemData (fallback)
    let itemType = this._str(src, 'itemType');
    if (itemType !== null && itemType.length > 0) {
      this._itemTypeName = itemType;
      this.itemData.set('itemType', itemType);
    }

    // 4. Common CSL fields — map directly into itemData
    this._mapField(src, 'title');
    this._mapField(src, 'abstractNote');
    this._mapField(src, 'date');
    this._mapField(src, 'DOI');
    this._mapField(src, 'ISBN');
    this._mapField(src, 'ISSN');
    this._mapField(src, 'url');
    this._mapField(src, 'accessDate');
    this._mapField(src, 'publicationTitle');
    this._mapField(src, 'publisher');
    this._mapField(src, 'place');
    this._mapField(src, 'pages');
    this._mapField(src, 'volume');
    this._mapField(src, 'issue');
    this._mapField(src, 'language');
    this._mapField(src, 'shortTitle');
    this._mapField(src, 'extra');
    this._mapField(src, 'archive');
    this._mapField(src, 'archiveLocation');
    this._mapField(src, 'libraryCatalog');
    this._mapField(src, 'callNumber');
    this._mapField(src, 'rights');
    this._mapField(src, 'series');
    this._mapField(src, 'seriesNumber');
    this._mapField(src, 'seriesTitle');
    this._mapField(src, 'journalAbbreviation');
    this._mapField(src, 'edition');
    this._mapField(src, 'numberOfVolumes');
    this._mapField(src, 'number');
    this._mapField(src, 'section');
    this._mapField(src, 'court');
    this._mapField(src, 'reporter');
    this._mapField(src, 'reporterVolume');
    this._mapField(src, 'citationKey');

    // 5. Creators (ref: item.js:5418-5435)
    this._parseCreators(src);

    // 6. Tags (ref: item.js:5324-5361)
    this._parseTags(src);

    // 7. Collections
    this._parseCollections(src);

    // 8. Relations (ref: dataObject.js:435-488)
    this._parseRelations(src);

    // 9. Parent item
    this._parseParentItem(src);

    // 10. Attachment fields (ref: item.js:5799-5818)
    this._parseAttachmentFields(src);

    // 11. Note fields (ref: item.js:5799-5804)
    this._parseNoteFields(src);

    // 12. Annotation fields (ref: item.js:5806-5818)
    this._parseAnnotationFields(src);
  }

  // ==================================================================
  // Private fromJSON helpers
  // ==================================================================

  /** Extract string value from record. Returns fallback if missing/null/not-string. */
  private _str(src: Record<string, Object>, key: string, fallback: string | null = null): string | null {
    let value = src[key];
    if (value === undefined || value === null || typeof value !== 'string') {
      return fallback;
    }
    return value;
  }

  /** Extract number value from record. Returns fallback if missing/null/not-number. */
  private _num(src: Record<string, Object>, key: string, fallback: number | null = null): number | null {
    let value = src[key];
    if (value === undefined || value === null) {
      return fallback;
    }
    if (typeof value === 'number') {
      return value;
    }
    return fallback;
  }

  /** Extract Object[] or null. */
  private _arr(src: Record<string, Object>, key: string): Object[] | null {
    let value = src[key];
    if (value === undefined || value === null || !Array.isArray(value)) {
      return null;
    }
    return value;
  }

  /**
   * Map a single scalar field from JSON into itemData.
   * Only sets if the value exists and is not null.
   */
  private _mapField(src: Record<string, Object>, fieldName: string): void {
    let value = src[fieldName];
    if (value === undefined || value === null) {
      return;
    }
    let str: string;
    if (typeof value === 'string') {
      str = value;
    } else if (typeof value === 'number') {
      str = `${value}`;
    } else {
      return;
    }
    if (str.length > 0) {
      this.itemData.set(fieldName, str);
    }
  }

  // -- Parse methods (ref: item.js loadFromObject subroutines) --

  private _parseCreators(src: Record<string, Object>): void {
    let arr = this._arr(src, 'creators');
    if (arr === null) {
      return;
    }
    let creators: ZoteroCreator[] = [];
    for (let i = 0; i < arr.length; i++) {
      let entry = arr[i] as Record<string, Object>;
      let creatorType = this._str(entry, 'creatorType') ?? 'author';
      let firstName = this._str(entry, 'firstName') ?? '';
      let lastName = this._str(entry, 'lastName') ?? '';
      let name = this._str(entry, 'name') ?? '';
      // fieldMode: 0 = two-field (first/last), 1 = single-field (name only)
      let fieldMode = 0;
      if (name.length > 0 && lastName.length === 0) {
        // Single-field creator: store in lastName per Zotero convention
        lastName = name;
        fieldMode = 1;
      }
      creators.push({ creatorType, firstName, lastName, fieldMode });
    }
    this._creators = creators;
    // Set _firstCreator for display (ref: item.js:43-44)
    if (creators.length > 0) {
      let first = creators[0];
      this._firstCreator = first.fieldMode === 0 && first.lastName.length > 0
        ? `${first.lastName}, ${first.firstName}`.replace(/,\s*$/, '')
        : (first.lastName || first.firstName);
    }
  }

  private _parseTags(src: Record<string, Object>): void {
    let arr = this._arr(src, 'tags');
    if (arr === null) {
      return;
    }
    let tags: ZoteroTag[] = [];
    for (let i = 0; i < arr.length; i++) {
      let entry = arr[i] as Record<string, Object>;
      let tag = this._str(entry, 'tag');
      if (tag === null || tag.length === 0) {
        continue;
      }
      let tagType = this._num(entry, 'type') ?? 0;
      tags.push({ tag, type: tagType });
    }
    this._tags = tags;
  }

  private _parseCollections(src: Record<string, Object>): void {
    let arr = this._arr(src, 'collections');
    if (arr === null) {
      return;
    }
    let keys: string[] = [];
    for (let i = 0; i < arr.length; i++) {
      if (typeof arr[i] === 'string') {
        keys.push(arr[i] as string);
      }
    }
    this._collectionKeys = keys;
  }

  private _parseRelations(src: Record<string, Object>): void {
    let rels = src['relations'];
    if (rels === undefined || rels === null || typeof rels !== 'object') {
      return;
    }
    let relMap: Record<string, string[]> = {};
    let relObj = rels as Record<string, Object>;
    let keys = Object.keys(relObj);
    for (let i = 0; i < keys.length; i++) {
      let predicate = keys[i];
      let objects = relObj[predicate];
      if (Array.isArray(objects)) {
        let values: string[] = [];
        for (let j = 0; j < objects.length; j++) {
          if (typeof objects[j] === 'string') {
            values.push(objects[j] as string);
          }
        }
        if (values.length > 0) {
          relMap[predicate] = values;
        }
      }
    }
    if (Object.keys(relMap).length > 0) {
      this.setRelations(relMap);
    }
  }

  private _parseParentItem(src: Record<string, Object>): void {
    let parent = src['parentItem'];
    if (parent === undefined || parent === null) {
      return;
    }
    if (typeof parent === 'string' && parent.length > 0) {
      this.parentKey = parent;
    }
    // parentItem can be boolean false in API responses — ignore in that case
  }

  private _parseAttachmentFields(src: Record<string, Object>): void {
    let linkMode = this._str(src, 'linkMode');
    if (linkMode !== null && linkMode.length > 0) {
      this._attachmentLinkMode = this._parseLinkMode(linkMode);
    }
    let contentType = this._str(src, 'contentType');
    if (contentType !== null) { this._attachmentContentType = contentType; }
    let charset = this._str(src, 'charset');
    if (charset !== null) { this._attachmentCharset = charset; }
    let path = this._str(src, 'path');
    if (path !== null) { this._attachmentPath = path; }
    // filename: if present, store as title in itemData (Zotero convention)
    let filename = this._str(src, 'filename');
    if (filename !== null && filename.length > 0) {
      this.itemData.set('filename', filename);
      // Fallback title for attachments
      if ((this.itemData.get('title') ?? '').length === 0) {
        this.itemData.set('title', filename);
      }
    }
    let hash = this._str(src, 'md5');
    if (hash === null) { hash = this._str(src, 'syncedHash'); }
    if (hash !== null) { this._attachmentSyncedHash = hash; }
    let mtime = this._num(src, 'mtime');
    if (mtime === null) { mtime = this._num(src, 'syncedModificationTime'); }
    if (mtime !== null) { this._attachmentSyncedModificationTime = mtime; }
  }

  private _parseNoteFields(src: Record<string, Object>): void {
    let note = this._str(src, 'note');
    if (note !== null) {
      this._noteText = note;
      // displayTitle: use first 80 chars of note text if no explicit title
      if (this._displayTitle === null && note.length > 0) {
        let plain = note.replace(/<[^>]+>/g, '').replace(/\s+/g, ' ').trim();
        this._displayTitle = plain.length > 80 ? plain.substring(0, 80) : plain;
      }
    }
    let title = this._str(src, 'title');
    if (title !== null && title.length > 0 && note !== null) {
      // For note items, the title field from API is the display title
      this._displayTitle = title;
    }
  }

  private _parseAnnotationFields(src: Record<string, Object>): void {
    let atype = this._str(src, 'annotationType');
    if (atype !== null) {
      this._annotationType = this._parseAnnotationType(atype);
    }
    let authorName = this._str(src, 'annotationAuthorName');
    if (authorName !== null) { this._annotationAuthorName = authorName; }
    let text = this._str(src, 'annotationText');
    if (text !== null) { this._annotationText = text; }
    let comment = this._str(src, 'annotationComment');
    if (comment !== null) { this._annotationComment = comment; }
    let color = this._str(src, 'annotationColor');
    if (color !== null) { this._annotationColor = color; }
    let pageLabel = this._str(src, 'annotationPageLabel');
    if (pageLabel !== null) { this._annotationPageLabel = pageLabel; }
    let sortIndex = this._str(src, 'annotationSortIndex');
    if (sortIndex !== null) { this._annotationSortIndex = sortIndex; }
    let position = this._str(src, 'annotationPosition');
    if (position !== null) { this._annotationPosition = position; }
  }

  /** Map Zotero API linkMode string → AttachmentLinkMode enum. */
  private _parseLinkMode(value: string): AttachmentLinkMode {
    let lower = value.toLowerCase();
    if (lower === 'linked_url')    { return AttachmentLinkMode.LINKED_URL; }
    if (lower === 'linked_file')   { return AttachmentLinkMode.LINKED_FILE; }
    if (lower === 'imported_url')  { return AttachmentLinkMode.IMPORTED_URL; }
    if (lower === 'embedded_image'){ return AttachmentLinkMode.EMBEDDED_IMAGE; }
    return AttachmentLinkMode.IMPORTED_FILE; // default / "imported_file"
  }

  /** Map Zotero API annotationType string → AnnotationTypeEnum. */
  private _parseAnnotationType(value: string): AnnotationTypeEnum {
    let lower = value.toLowerCase();
    if (lower === 'underline') { return AnnotationTypeEnum.UNDERLINE; }
    if (lower === 'note')      { return AnnotationTypeEnum.NOTE; }
    if (lower === 'image')     { return AnnotationTypeEnum.IMAGE; }
    if (lower === 'ink')       { return AnnotationTypeEnum.INK; }
    if (lower === 'text')      { return AnnotationTypeEnum.TEXT; }
    return AnnotationTypeEnum.HIGHLIGHT;
  }
}
