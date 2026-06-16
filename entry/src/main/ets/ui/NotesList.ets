/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: elements/notesBox.js — child notes list for an item
 *
 * ***** END LICENSE BLOCK *****
 */

/** Minimal note data for list display. */
export interface NoteEntry {
  id: number;
  key: string | null;
  title: string;
  /** First ~120 chars of note content for preview. */
  preview: string;
  dateModified: string;
  noteText?: string;
}

@Component
struct NoteRow {
  @Prop note: NoteEntry = { id: 0, key: null, title: '', preview: '', dateModified: '' };
  onOpen?: (id: number) => void;
  onDelete?: (id: number) => void;

  build() {
    Row() {
      Column() {
        Text(this.note.title || '(untitled)')
          .fontSize(14).fontColor('#333').fontWeight(FontWeight.Medium)
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.note.preview)
          .fontSize(12).fontColor('#999').maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12, top: 6, bottom: 6 })

      Button('✕').fontSize(12).width(28).height(28)
        .backgroundColor('#00000000').fontColor('#999')
        .margin({ right: 4 })
        .onClick(() => { if (this.onDelete) { this.onDelete(this.note.id); } })
    }
    .width('100%')
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
    .onClick(() => { if (this.onOpen) { this.onOpen(this.note.id); } })
  }
}

/**
 * Child notes list panel.
 * Ref: elements/notesBox.js
 */
@Component
export struct NotesList {
  @Link notes: NoteEntry[];
  @Prop readOnly: boolean = false;
  onNoteOpen?: (id: number) => void;
  onNoteDelete?: (id: number) => void;
  onNoteAdd?: () => void;

  build() {
    Column() {
      Row() {
        Text('NOTES')
          .fontSize(11).fontColor('#888').fontWeight(FontWeight.Medium)
          .layoutWeight(1)
        if (!this.readOnly) {
          Button('+ Add').fontSize(12).height(28)
            .onClick(() => { if (this.onNoteAdd) { this.onNoteAdd(); } })
        }
      }
      .width('100%').padding({ left: 12, right: 12, top: 8, bottom: 4 })

      if (this.notes.length === 0) {
        Text('No notes').fontSize(13).fontColor('#CCC')
          .padding({ left: 12, bottom: 8 })
      } else {
        List() {
          ForEach(this.notes, (note: NoteEntry) => {
            ListItem() {
              NoteRow({
                note: note,
                onOpen: this.onNoteOpen,
                onDelete: (id: number) => {
                  this.notes = this.notes.filter((n: NoteEntry) => n.id !== id);
                  if (this.onNoteDelete) { this.onNoteDelete(id); }
                },
              })
            }
          }, (note: NoteEntry): string => `note-${note.id}`)
        }
        .height(Math.min(this.notes.length * 60, 300))
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .border({ width: { top: 1 }, color: '#EEEEEE' })
  }
}
