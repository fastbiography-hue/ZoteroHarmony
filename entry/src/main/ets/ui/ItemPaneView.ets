/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: elements/itemPane.js — deck-based view switcher
 *
 * Replaces XUL <deck> with ArkUI conditional rendering:
 *   MessagePane | ItemDetailsForm | NoteEditor | Duplicates | Annotations
 *
 * ***** END LICENSE BLOCK *****
 */

import { router } from '@kit.ArkUI';
import { ItemModel } from '../model/ItemModel.ets';
import { ItemDetailsForm } from './ItemDetailsForm.ets';
import { AbstractEditor } from './AbstractEditor.ets';
import { AttachmentsList, AttachmentEntry } from './AttachmentsList.ets';
import { NotesList, NoteEntry } from './NotesList.ets';
import { RelatedItems, RelatedItemRef } from './RelatedItems.ets';
import { TagChipEditor } from './TagChipEditor.ets';
import { ZoteroTag, AttachmentLinkMode } from '../model/ItemTypes.ets';
import { ZHColor, ZHMetric } from '../theme/ThemeConstants.ets';
import { readerManager } from '../reader/ReaderManager.ets';
import { LibraryRepository } from '../database/LibraryRepository.ets';
import { QuickCopy } from '../clipboard/QuickCopy.ets';
import { AppStore } from '../utils/AppStore.ets';

export type PaneView = 'message' | 'details' | 'attachments' | 'notes' | 'tags' | 'related' | 'note' | 'duplicates' | 'annotations';

/**
 * Item pane container — switches between views based on item state.
 *
 * Ref: itemPane.js  constructor + notify() + deck selectedIndex
 */
@Component
export struct ItemPaneView {
  @Watch('reloadContent')
  @Link item: ItemModel;
  @Link selectedView: PaneView;
  @State abstractText: string = '';
  @State attachments: AttachmentEntry[] = [];
  @State notes: NoteEntry[] = [];
  @State tags: ZoteroTag[] = [];
  @State related: RelatedItemRef[] = [];
  @State selectedNoteID: number = 0;
  @State selectedNoteTitle: string = '';
  @State selectedNoteText: string = '';
  @State noteLoaded: boolean = false;
  // Attachment draft fields
  @State attachTitle: string = '';
  @State attachContentType: string = '';
  @State attachPath: string = '';
  @State attachUrl: string = '';
  @State attachIsDirty: boolean = false;
  @State attachSaveStatus: 'idle' | 'dirty' | 'success' | 'error' = 'idle';
  @State attachSaveMessage: string = '';
  @State initialAttachTitle: string = '';
  @State initialAttachContentType: string = '';
  @State initialAttachPath: string = '';
  @State initialAttachUrl: string = '';
  @Watch('_refreshFromStore')
  @StorageLink('zotero_libraryRevision') libraryRevision: number = 0;
  @Prop currentItemPendingSync: boolean = false;
  onItemSaved?: () => void;

  aboutToAppear(): void {
    this._reload();
  }

  private _reload(): void {
    this.abstractText = this.item.itemData.get('abstractNote') ?? '';
    this.tags = [...this.item.tags];
    if (this.item.isAttachment()) {
      this._clearNoteDraft();
      this._initAttachmentDraft();
    } else if (this.item.isNote()) {
      this._clearAttachmentDraftStatus();
      this._loadNoteForChild();
    } else {
      this._clearNoteDraft();
      this._clearAttachmentDraftStatus();
      this._loadAttachments();
      this._loadNotes();
      this._loadRelated();
    }
  }

  private _clearNoteDraft(): void {
    this.noteLoaded = false;
    this.selectedNoteID = 0;
    this.selectedNoteTitle = '';
    this.selectedNoteText = '';
  }

  private _clearAttachmentDraftStatus(): void {
    this.attachIsDirty = false;
    this.attachSaveStatus = 'idle';
    this.attachSaveMessage = '';
  }

  /** If a note child item is selected, auto-load its body. */
  private _loadNoteForChild(): void {
    // Clear old note state before async load
    this._clearNoteDraft();
    let noteKey = this.item.key ?? '';
    if (noteKey.length === 0) { return; }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.getNoteByKey(noteKey);
    }).then((n) => {
      if (n) {
        this.selectedNoteID = n.id;
        this.selectedNoteTitle = n.title || this.item.displayTitle || '';
        this.selectedNoteText = n.noteText;
        this.noteLoaded = true;
        this.selectedView = 'note';
      }
      repo.close();
    }).catch((_err: Error) => { repo.close(); });
  }

  /** Init attachment metadata draft from current item. */
  private _initAttachmentDraft(): void {
    this.attachTitle = this.item.itemData.get('title') ?? '';
    this.attachContentType = this.item.attachmentContentType ?? '';
    this.attachPath = this.item.attachmentPath ?? '';
    this.attachUrl = this.item.itemData.get('url') ?? '';
    this.initialAttachTitle = this.attachTitle;
    this.initialAttachContentType = this.attachContentType;
    this.initialAttachPath = this.attachPath;
    this.initialAttachUrl = this.attachUrl;
    this.attachIsDirty = false;
    this.attachSaveStatus = 'idle';
    this.attachSaveMessage = '';
  }

  private _updateAttachmentDirty(): void {
    let dirty =
      this.attachTitle !== this.initialAttachTitle ||
      this.attachContentType !== this.initialAttachContentType ||
      this.attachPath !== this.initialAttachPath ||
      this.attachUrl !== this.initialAttachUrl;
    this.attachIsDirty = dirty;
    if (dirty && this.attachSaveStatus === 'idle') {
      this.attachSaveStatus = 'dirty';
    } else if (!dirty && this.attachSaveStatus === 'dirty') {
      this.attachSaveStatus = 'idle';
    }
  }

  /** Pure helper for testability — exported. */
  static attachmentDraftDirty(
    initial: { title: string; contentType: string; path: string; url: string },
    current: { title: string; contentType: string; path: string; url: string }
  ): boolean {
    return initial.title !== current.title ||
      initial.contentType !== current.contentType ||
      initial.path !== current.path ||
      initial.url !== current.url;
  }

  private reloadContent(): void {
    this._reload();
  }

  private _refreshFromStore(): void {
    this._reload();
  }

  build() {
    // ---- Attachment child item detail form ----
    if (this.item.isAttachment()) {
      Column() {
        this._itemHeader()
        Scroll() {
          Column() {
            this._sectionHeader('ATTACHMENT METADATA')
            this._readOnlyRow('Link Mode', this._linkModeLabel(this.item.attachmentLinkMode))
            this._readOnlyRow('Parent Item', this.item.parentKey ?? '(none)')
            this._editRow('Title', this.attachTitle, (v: string) => { this.attachTitle = v; this._updateAttachmentDirty(); })
            this._editRow('Content Type', this.attachContentType, (v: string) => { this.attachContentType = v; this._updateAttachmentDirty(); })
            this._editRow('Path', this.attachPath, (v: string) => { this.attachPath = v; this._updateAttachmentDirty(); })
            this._editRow('URL', this.attachUrl, (v: string) => { this.attachUrl = v; this._updateAttachmentDirty(); })
            Blank().height(20)
            // Status bar
            Row() {
              if (this.attachSaveStatus === 'success') {
                Text(this.attachSaveMessage).fontSize(11).fontColor('#2E7D32').layoutWeight(1)
              } else if (this.attachSaveStatus === 'error') {
                Text(this.attachSaveMessage).fontSize(11).fontColor('#C62828').layoutWeight(1)
              } else if (this.attachIsDirty) {
                Text('Unsaved changes').fontSize(11).fontColor(ZHColor.WARNING).layoutWeight(1)
              } else { Blank().layoutWeight(1) }
              Button('Reset').fontSize(11).height(28).margin({ right: 6 })
                .enabled(this.attachIsDirty).onClick(() => { this._initAttachmentDraft(); })
              Button('Open').fontSize(11).height(28).margin({ right: 6 })
                .backgroundColor(ZHColor.SURFACE_ALT).fontColor(ZHColor.TEXT)
                .onClick(() => {
                  let filePath = this.attachPath.length > 0 ? this.attachPath :
                    (this.attachUrl.length > 0 ? this.attachUrl : '');
                  let title = this.attachTitle || this.item.itemData.get('title') || 'Attachment';
                  readerManager.open(this.item.id ?? 0, this.item.key ?? '', title, filePath, 1);
                  router.pushUrl({ url: 'reader/ReaderPage', params: { itemKey: this.item.key ?? '' } });
                })
              Button('Save').fontSize(11).height(28)
                .enabled(this.attachIsDirty).backgroundColor(ZHColor.BRAND).fontColor(ZHColor.TEXT_INVERSE)
                .onClick(() => { this._saveAttachment(); })
              Button('Delete').fontSize(11).height(28).margin({ left: 6 })
                .backgroundColor(ZHColor.BRAND_SOFT).fontColor(ZHColor.BRAND)
                .onClick(() => { this._deleteCurrentAttachment(); })
            }
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
          }
        }
        .layoutWeight(1).scrollBar(BarState.Auto)
      }
      .width('100%').height('100%').backgroundColor(ZHColor.SURFACE)
      return
    }

    // ---- Note child item editor ----
    if (this.item.isNote() && this.noteLoaded) {
      Column() {
        this._itemHeader()
        Column() {
          TextInput({ placeholder: 'Note title', text: this.selectedNoteTitle })
            .fontSize(15).height(38)
            .margin({ left: 12, right: 12, top: 10, bottom: 8 })
            .onChange((value: string) => { this.selectedNoteTitle = value; })
          AbstractEditor({
            label: 'NOTE',
            text: this.selectedNoteText,
            minHeight: 220,
            onChange: (v: string) => { this.selectedNoteText = v; },
          })
          Row() {
            Button('Save Note').fontSize(12).height(32)
              .backgroundColor(ZHColor.BRAND).fontColor(ZHColor.TEXT_INVERSE)
              .onClick(() => { this._saveNoteForChild(); })
            Button('Delete Note').fontSize(12).height(32).margin({ left: 8 })
              .backgroundColor(ZHColor.BRAND_SOFT).fontColor(ZHColor.BRAND)
              .onClick(() => { this._deleteCurrentNote(); })
          }
          .padding({ left: 12, right: 12, top: 10, bottom: 10 })
        }
        .layoutWeight(1)
      }
      .width('100%').height('100%').backgroundColor(ZHColor.SURFACE)
      return
    }

    // ---- Default regular item pane ----
    Row() {
      Column() {
        this._sidenavButton('details', 'Info')
        this._sidenavButton('attachments', 'Files')
        this._sidenavButton('notes', 'Notes')
        this._sidenavButton('tags', 'Tags')
        this._sidenavButton('related', 'Related')
        Blank().layoutWeight(1)
      }
      .width(88)
      .height('100%')
      .padding({ top: 8, left: 6, right: 6, bottom: 8 })
      .backgroundColor(ZHColor.SURFACE_ALT)
      .border({ width: { right: 1 }, color: ZHColor.BORDER })

      Column() {
        this._itemHeader()

        // View switcher tabs for compact familiarity with Zotero sections
        Row() {
          this._topTab('details', 'Info')
          this._topTab('attachments', 'Files')
          this._topTab('notes', 'Notes')
          this._topTab('tags', 'Tags')
          this._topTab('related', 'Related')
        }
        .width('100%')
        .border({ width: { bottom: 1 }, color: ZHColor.BORDER_SOFT })

        // Content area
        if (this.selectedView === 'details') {
          Scroll() {
            Column() {
              // abstractNote is now edited inside ItemDetailsForm's FieldEditor.
              ItemDetailsForm({
                item: this.item,
                itemKey: this.item.key ?? '',
                itemRevision: this.libraryRevision,
                onItemSaved: this.onItemSaved,
              })
            }
            .width('100%')
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
        } else if (this.selectedView === 'attachments') {
          AttachmentsList({
            attachments: $attachments,
            onAttachmentOpen: (id: number) => {
              let attachment: AttachmentEntry | null = null;
              for (let i = 0; i < this.attachments.length; i++) {
                if (this.attachments[i].id === id) {
                  attachment = this.attachments[i];
                  break;
                }
              }
              let itemKey = attachment?.key ?? this.item.key ?? `attachment-${id}`;
              let filePath = attachment?.path ?? this.item.attachmentPath ?? '';
              let title = attachment?.filename ?? this.item.itemData.get('title') ?? 'Reader';
              readerManager.open(this.item.id ?? id, itemKey, title, filePath, 1);
              router.pushUrl({ url: 'reader/ReaderPage', params: { itemKey: itemKey } });
            },
            onAttachmentAdd: () => {
              this._addLinkedUrlAttachment();
            },
            onAttachmentDelete: (key: string) => {
              this._deleteAttachment(key);
            },
          })
          .layoutWeight(1)
        } else if (this.selectedView === 'notes') {
          NotesList({
            notes: $notes,
            onNoteOpen: (id: number) => { this._openNote(id); },
            onNoteAdd: () => {
              this._createNote();
            },
            onNoteDelete: (id: number) => { this._deleteNote(id); },
          })
          .layoutWeight(1)
        } else if (this.selectedView === 'tags') {
          Scroll() {
            TagChipEditor({
              tags: $tags,
              readOnly: false,
              onTagsChange: (tags: ZoteroTag[]) => {
                this._saveTags(tags);
              },
            })
          }
          .layoutWeight(1)
          .scrollBar(BarState.Auto)
        } else if (this.selectedView === 'related') {
          RelatedItems({
            related: $related,
            onItemAdd: () => { this._addRelatedItems(); },
            onItemRemove: (key: string) => { this._removeRelatedItem(key); },
            onItemSelect: (_key: string) => { this.selectedView = 'details'; },
          })
          .layoutWeight(1)
        } else if (this.selectedView === 'note') {
          Column() {
            TextInput({ placeholder: 'Note title', text: this.selectedNoteTitle })
              .fontSize(15)
              .height(38)
              .margin({ left: 12, right: 12, top: 10, bottom: 8 })
              .onChange((value: string) => { this.selectedNoteTitle = value; })
            AbstractEditor({
              label: 'NOTE',
              text: this.selectedNoteText,
              minHeight: 220,
              onChange: (v: string) => { this.selectedNoteText = v; },
            })
            Row() {
              Button('Save Note')
                .fontSize(12)
                .height(32)
                .onClick(() => { this._saveNote(); })
              Button('Delete Note')
                .fontSize(12)
                .height(32)
                .margin({ left: 8 })
                .backgroundColor(ZHColor.BRAND_SOFT)
                .fontColor(ZHColor.BRAND)
                .onClick(() => { this._deleteNote(this.selectedNoteID); })
            }
            .padding({ left: 12, right: 12, top: 10, bottom: 10 })
          }
          .layoutWeight(1)
        }
      }
      .layoutWeight(1)
      .height('100%')
      .backgroundColor(ZHColor.SURFACE)
    }
    .width('100%').height('100%')
  }

  @Builder
  _itemHeader() {
    Column() {
      Row() {
        Text((this.item.itemData.get('itemType') ?? 'journalArticle') === 'book' ? 'B' :
          ((this.item.itemData.get('itemType') ?? 'journalArticle') === 'conferencePaper' ? 'C' :
            ((this.item.itemData.get('itemType') ?? 'journalArticle') === 'note' ? 'N' :
              ((this.item.itemData.get('itemType') ?? 'journalArticle') === 'attachment' ? 'A' : 'J'))))
          .fontSize(11)
          .fontColor(ZHColor.BRAND)
          .fontWeight(FontWeight.Bold)
          .width(28)
          .height(24)
          .textAlign(TextAlign.Center)
          .backgroundColor(ZHColor.BRAND_SOFT)
          .borderRadius(ZHMetric.RADIUS_SMALL)
          .margin({ right: 10 })
        Column() {
          Text(this.item.itemData.get('title') ?? 'Untitled Item')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(ZHColor.TEXT)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Row() {
            if ((this.item.itemData.get('creator') ?? '').length > 0) {
              Text(this.item.itemData.get('creator') ?? '')
                .fontSize(12)
                .fontColor(ZHColor.TEXT_MUTED)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            if ((this.item.itemData.get('date') ?? '').length > 0) {
              Text(' · ' + (this.item.itemData.get('date') ?? ''))
                .fontSize(12)
                .fontColor(ZHColor.TEXT_MUTED)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            if ((this.item.itemData.get('publisher') ?? '').length > 0) {
              Text(' · ' + (this.item.itemData.get('publisher') ?? ''))
                .fontSize(12)
                .fontColor(ZHColor.TEXT_MUTED)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .width('100%')
          if (this.currentItemPendingSync) {
            Text('● Pending sync')
              .fontSize(11).fontColor('#E65100')
              .margin({ top: 3 })
          }
        }
        .layoutWeight(1)
      }
      .width('100%')
    }
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor(ZHColor.SURFACE)
    .border({ width: { bottom: 1 }, color: ZHColor.BORDER_SOFT })
  }

  @Builder
  _topTab(view: PaneView, label: string) {
    Text(label)
      .fontSize(13)
      .fontColor(this.selectedView === view ? ZHColor.BRAND : ZHColor.TEXT_MUTED)
      .fontWeight(this.selectedView === view ? FontWeight.Medium : FontWeight.Normal)
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .border({ width: { bottom: this.selectedView === view ? 2 : 0 }, color: ZHColor.BRAND })
      .onClick(() => { this.selectedView = view; })
  }

  @Builder
  _sidenavButton(view: PaneView, label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.selectedView === view ? ZHColor.TEXT : ZHColor.TEXT_MUTED)
      .fontWeight(this.selectedView === view ? FontWeight.Bold : FontWeight.Normal)
      .width('100%')
      .height(32)
      .textAlign(TextAlign.Center)
      .backgroundColor(this.selectedView === view ? ZHColor.SELECTED_STRONG : ZHColor.TRANSPARENT)
      .borderRadius(ZHMetric.RADIUS_SMALL)
      .margin({ bottom: 4 })
      .onClick(() => { this.selectedView = view; })
  }

  // ---- Attachment child-item helpers ----

  private _saveAttachment(): void {
    let itemKey = this.item.key ?? '';
    if (itemKey.length === 0) { return; }
    this.attachSaveStatus = 'dirty';
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.updateAttachmentMetadataByKey(itemKey, this.attachTitle,
        this.attachContentType, this.attachPath, this.attachUrl);
    }).then(() => {
      repo.close();
      // Sync ItemModel: title/url match Repository behaviour (write or delete)
      if (this.attachTitle.length > 0) {
        this.item.itemData.set('title', this.attachTitle);
      } else {
        this.item.itemData.delete('title');
      }
      if (this.attachUrl.length > 0) {
        this.item.itemData.set('url', this.attachUrl);
      } else {
        this.item.itemData.delete('url');
      }
      this.item.attachmentContentType = this.attachContentType;
      this.item.attachmentPath = this.attachPath;
      // Update initial snapshots so dirty resets
      this.initialAttachTitle = this.attachTitle;
      this.initialAttachContentType = this.attachContentType;
      this.initialAttachPath = this.attachPath;
      this.initialAttachUrl = this.attachUrl;
      this.attachIsDirty = false;
      this.attachSaveStatus = 'success';
      this.attachSaveMessage = 'Saved locally, pending sync';
      if (this.onItemSaved) { this.onItemSaved(); }
    }).catch((err: Error) => {
      repo.close();
      this.attachSaveStatus = 'error';
      this.attachSaveMessage = 'Save failed: ' + err.message;
    });
  }

  private _deleteCurrentAttachment(): void {
    let itemKey = this.item.key ?? '';
    if (itemKey.length === 0) { return; }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.deleteAttachment(itemKey);
    }).then(() => {
      repo.close();
      if (this.onItemSaved) { this.onItemSaved(); }
    }).catch((_err: Error) => { repo.close(); });
  }

  private _saveNoteForChild(): void {
    let noteKey = this.item.key ?? '';
    if (noteKey.length === 0 || this.selectedNoteID === 0) { return; }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.updateNoteByKey(noteKey, this.selectedNoteTitle, this.selectedNoteText);
    }).then(() => {
      repo.close();
      this.item.displayTitle = this.selectedNoteTitle;
      this.item.noteText = this.selectedNoteText;
      if (this.onItemSaved) { this.onItemSaved(); }
    }).catch((_err: Error) => { repo.close(); });
  }

  private _deleteCurrentNote(): void {
    if (this.selectedNoteID === 0) { return; }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.deleteNote(this.selectedNoteID);
    }).then(() => {
      repo.close();
      this.selectedNoteID = 0;
      this.selectedNoteTitle = '';
      this.selectedNoteText = '';
      if (this.onItemSaved) { this.onItemSaved(); }
    }).catch((_err: Error) => { repo.close(); });
  }

  @Builder
  _readOnlyRow(label: string, value: string) {
    Row() {
      Text(label).fontSize(11).fontColor('#888').width(90)
      Text(value).fontSize(14).fontColor(ZHColor.TEXT).layoutWeight(1)
    }
    .width('100%').padding({ left: 14, right: 14, top: 6, bottom: 6 })
    .border({ width: { bottom: 0.5 }, color: '#EEEEEE' })
  }

  @Builder
  _editRow(label: string, value: string, onChange: (v: string) => void) {
    Row() {
      Text(label).fontSize(11).fontColor('#888').width(90)
      TextInput({ text: value }).fontSize(14).layoutWeight(1).height(36)
        .onChange(onChange)
    }
    .width('100%').padding({ left: 14, right: 14, top: 6, bottom: 6 })
    .border({ width: { bottom: 0.5 }, color: '#EEEEEE' })
  }

  @Builder
  _sectionHeader(title: string) {
    Text(title)
      .fontSize(12).fontColor('#999').fontWeight(FontWeight.Bold).width('100%')
      .padding({ left: 14, top: 12, bottom: 4 })
  }

  private _linkModeLabel(mode: AttachmentLinkMode | null): string {
    if (mode === null) { return 'unknown'; }
    if (mode === AttachmentLinkMode.IMPORTED_FILE) { return 'Imported File'; }
    if (mode === AttachmentLinkMode.IMPORTED_URL) { return 'Imported URL'; }
    if (mode === AttachmentLinkMode.LINKED_FILE) { return 'Linked File'; }
    if (mode === AttachmentLinkMode.LINKED_URL) { return 'Linked URL'; }
    if (mode === AttachmentLinkMode.EMBEDDED_IMAGE) { return 'Embedded Image'; }
    return 'unknown';
  }

  // ---- Regular item helpers ----

  private _saveTags(tags: ZoteroTag[]): void {
    this.item.tags = tags;
    let itemKey = this.item.key ?? '';
    if (itemKey.length === 0) {
      return;
    }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.replaceItemTags(itemKey, tags);
    }).then(() => {
      repo.close();
    }).catch((_err: Error) => {
      repo.close();
    });
  }

  private _loadAttachments(): void {
    let itemKey = this.item.key ?? '';
    if (itemKey.length === 0) {
      this.attachments = [];
      return;
    }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.listAttachments(itemKey);
    }).then((attachments: AttachmentEntry[]) => {
      this.attachments = attachments;
      repo.close();
    }).catch((_err: Error) => {
      this.attachments = [];
      repo.close();
    });
  }

  private _loadNotes(): void {
    let itemKey = this.item.key ?? '';
    if (itemKey.length === 0) {
      this.notes = [];
      return;
    }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.listNotes(itemKey);
    }).then((notes: NoteEntry[]) => {
      this.notes = notes;
      repo.close();
    }).catch((_err: Error) => {
      this.notes = [];
      repo.close();
    });
  }

  private _openNote(noteID: number): void {
    for (let i = 0; i < this.notes.length; i++) {
      if (this.notes[i].id === noteID) {
        this.selectedNoteID = noteID;
        this.selectedNoteTitle = this.notes[i].title;
        this.selectedNoteText = this.notes[i].noteText ?? this.notes[i].preview;
        this.selectedView = 'note';
        return;
      }
    }
  }

  private _createNote(): void {
    let itemKey = this.item.key ?? '';
    if (itemKey.length === 0) {
      return;
    }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.createNote(itemKey, 'New Note', '');
    }).then((noteKey: string) => {
      if (noteKey.length > 0) {
        return repo.listNotes(itemKey).then((notes: NoteEntry[]) => {
          this.notes = notes;
          this._selectNoteByKey(noteKey);
        });
      }
    }).catch((_err: Error) => {
    }).finally(() => {
      repo.close();
    });
  }

  private _selectNoteByKey(noteKey: string): void {
    for (let i = 0; i < this.notes.length; i++) {
      if ((this.notes[i].key ?? '') === noteKey) {
        this.selectedNoteID = this.notes[i].id;
        this.selectedNoteTitle = this.notes[i].title;
        this.selectedNoteText = this.notes[i].noteText ?? this.notes[i].preview;
        this.selectedView = 'note';
        return;
      }
    }
    this.selectedView = 'notes';
  }

  private _saveNote(): void {
    if (this.selectedNoteID === 0) {
      return;
    }
    let noteID = this.selectedNoteID;
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.updateNote(noteID, this.selectedNoteTitle, this.selectedNoteText);
    }).then(() => {
      this._loadNotes();
      repo.close();
    }).catch((_err: Error) => {
      repo.close();
    });
  }

  private _deleteNote(noteID: number): void {
    if (noteID === 0) {
      return;
    }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.deleteNote(noteID);
    }).then(() => {
      if (this.selectedNoteID === noteID) {
        this.selectedNoteID = 0;
        this.selectedNoteTitle = '';
        this.selectedNoteText = '';
        this.selectedView = 'notes';
      }
      this._loadNotes();
      repo.close();
    }).catch((_err: Error) => {
      repo.close();
    });
  }

  private _addLinkedUrlAttachment(): void {
    let itemKey = this.item.key ?? '';
    if (itemKey.length === 0) {
      return;
    }
    QuickCopy.readText().then((text: string) => {
      let repo = new LibraryRepository();
      return repo.open(getContext(this).getApplicationContext()).then(() => {
        return repo.createLinkedUrlAttachment(itemKey, text.trim()).then(() => {
          return repo.close();
        }).then(() => {
          this._loadAttachments();
        });
      });
    }).catch((_err: Error) => {});
  }

  private _deleteAttachment(itemKey: string): void {
    if (itemKey.length === 0) {
      return;
    }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.deleteAttachment(itemKey);
    }).then(() => {
      this._loadAttachments();
      repo.close();
    }).catch((_err: Error) => {
      repo.close();
    });
  }

  private _loadRelated(): void {
    let itemKey = this.item.key ?? '';
    if (itemKey.length === 0) {
      this.related = [];
      return;
    }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.listRelatedItems(itemKey);
    }).then((related: RelatedItemRef[]) => {
      this.related = related;
      repo.close();
    }).catch((_err: Error) => {
      this.related = [];
      repo.close();
    });
  }

  private _addRelatedItems(): void {
    let itemKey = this.item.key ?? '';
    if (itemKey.length === 0) {
      return;
    }
    router.pushUrl({
      url: 'pages/SelectItemsDialog',
      params: { itemKey: itemKey, mode: 'related' },
    });
  }

  private _removeRelatedItem(relatedKey: string): void {
    let itemKey = this.item.key ?? '';
    if (itemKey.length === 0 || relatedKey.length === 0) {
      return;
    }
    let repo = new LibraryRepository();
    repo.open(getContext(this).getApplicationContext()).then(() => {
      return repo.removeRelatedItem(itemKey, relatedKey);
    }).then(() => {
      AppStore.libraryRevision = AppStore.libraryRevision + 1;
      this._loadRelated();
      repo.close();
    }).catch((_err: Error) => {
      repo.close();
    });
  }
}
