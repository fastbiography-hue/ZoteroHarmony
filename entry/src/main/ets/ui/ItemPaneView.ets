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
import { ZoteroTag } from '../model/ItemTypes.ets';
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
  @Watch('_refreshFromStore')
  @StorageLink('zotero_libraryRevision') libraryRevision: number = 0;

  aboutToAppear(): void {
    this._reload();
  }

  private _reload(): void {
    this.abstractText = this.item.itemData.get('abstractNote') ?? '';
    this.tags = [...this.item.tags];
    this._loadAttachments();
    this._loadNotes();
    this._loadRelated();
  }

  private reloadContent(): void {
    this._reload();
  }

  private _refreshFromStore(): void {
    this._reload();
  }

  build() {
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
              ItemDetailsForm({
                item: this.item,
              })
              AbstractEditor({
                text: this.abstractText,
                onChange: (v: string) => { this.abstractText = v; },
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
