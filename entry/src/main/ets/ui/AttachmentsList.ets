/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: elements/attachmentsBox.js — file attachment list
 *
 * ***** END LICENSE BLOCK *****
 */

/** Minimal attachment data model. */
export interface AttachmentEntry {
  id: number;
  key: string;
  filename: string;
  contentType: string;
  linkMode: string;   // 'imported_file' | 'linked_file' | 'linked_url'
  path?: string;
  syncState?: number; // 0=pending, 1=synced, 2=syncing, 3=error
}

/** File type → icon mapping. */
const FILE_ICONS: Record<string, string> = {
  'application/pdf': '📕',
  'text/html':       '🌐',
  'image/':          '🖼',
  'audio/':          '🎵',
  'video/':          '🎬',
  'text/':           '📄',
};

function iconForType(ct: string): string {
  let keys = Object.keys(FILE_ICONS);
  for (let i = 0; i < keys.length; i++) {
    if (ct.startsWith(keys[i])) { return FILE_ICONS[keys[i]]; }
  }
  return '📎';
}

function linkModeLabel(linkMode: string): string {
  if (linkMode === 'imported_file') { return 'Imported file'; }
  if (linkMode === 'imported_url') { return 'Imported URL'; }
  if (linkMode === 'linked_url') { return 'Linked URL'; }
  return 'Linked file';
}

@Component
struct AttachmentRow {
  @Prop attachment: AttachmentEntry = { id: 0, key: '', filename: '', contentType: '', linkMode: 'imported_file' };
  onOpen?: (id: number) => void;
  onDelete?: (id: number) => void;

  build() {
    Row() {
      Text(iconForType(this.attachment.contentType))
        .fontSize(18).margin({ right: 10 })

      Column() {
        Text(this.attachment.filename || 'Untitled')
          .fontSize(14).fontColor('#333').maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.attachment.contentType || 'Unknown type')
          .fontSize(11).fontColor('#999')
        Text(linkModeLabel(this.attachment.linkMode))
          .fontSize(10).fontColor('#8C96A3')
        Text(this.attachment.syncState === 1 ? 'Synced' :
          (this.attachment.syncState === 2 ? 'Syncing' :
            (this.attachment.syncState === 3 ? 'File sync error' : 'Pending file sync')))
          .fontSize(10)
          .fontColor(this.attachment.syncState === 3 ? '#B4282E' : '#8C96A3')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button('Open').fontSize(11).height(28)
        .onClick(() => { if (this.onOpen) { this.onOpen(this.attachment.id); } })
        .margin({ left: 4 })

      Button('✕').fontSize(12).width(28).height(28)
        .backgroundColor('#00000000').fontColor('#999')
        .onClick(() => { if (this.onDelete) { this.onDelete(this.attachment.id); } })
    }
    .width('100%').padding({ left: 12, right: 8, top: 6, bottom: 6 })
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
  }
}

/**
 * List of file attachments with open/delete actions.
 * Ref: elements/attachmentsBox.js
 */
@Component
export struct AttachmentsList {
  @Link attachments: AttachmentEntry[];
  @Prop readOnly: boolean = false;
  onAttachmentOpen?: (id: number) => void;
  onAttachmentDelete?: (key: string) => void;
  onAttachmentAdd?: () => void;

  build() {
    Column() {
      Row() {
        Text('ATTACHMENTS')
          .fontSize(11).fontColor('#888').fontWeight(FontWeight.Medium)
          .layoutWeight(1)
        if (!this.readOnly) {
          Button('+ Add').fontSize(12).height(28)
            .onClick(() => { if (this.onAttachmentAdd) { this.onAttachmentAdd(); } })
        }
      }
      .width('100%').padding({ left: 12, right: 12, top: 8, bottom: 4 })

      if (this.attachments.length === 0) {
        Text('No attachments').fontSize(13).fontColor('#CCC')
          .padding({ left: 12, bottom: 8 })
      } else {
        List() {
          ForEach(this.attachments, (att: AttachmentEntry) => {
            ListItem() {
              AttachmentRow({
                attachment: att,
                onOpen: this.onAttachmentOpen,
                onDelete: (_id: number) => {
                  this.attachments = this.attachments.filter((a: AttachmentEntry) => a.id !== att.id);
                  if (this.onAttachmentDelete) { this.onAttachmentDelete(att.key); }
                },
              })
            }
          }, (att: AttachmentEntry): string => `att-${att.id}`)
        }
        .height(Math.min(this.attachments.length * 52, 260))
        .scrollBar(BarState.Auto)
      }
    }
    .width('100%')
    .border({ width: { top: 1 }, color: '#EEEEEE' })
  }
}
