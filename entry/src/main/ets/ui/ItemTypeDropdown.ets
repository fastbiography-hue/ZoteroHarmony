/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ported from Zotero Desktop (AGPL-3.0)
 * Ref: elements/itemPaneHeader.js — item type selector + icon
 *
 * ***** END LICENSE BLOCK *****
 */

import { ItemFieldsMeta } from '../model/ItemFieldsMeta.ets';
import { ItemType, CSLField } from '../model/ItemTypes.ets';

/** Human-readable labels for ItemType enum values. */
const ITEM_TYPE_LABELS: Record<ItemType, string> = {
  [ItemType.JOURNAL_ARTICLE]:      'Journal Article',
  [ItemType.BOOK]:                 'Book',
  [ItemType.BOOK_SECTION]:         'Book Section',
  [ItemType.CONFERENCE_PAPER]:     'Conference Paper',
  [ItemType.THESIS]:               'Thesis',
  [ItemType.REPORT]:               'Report',
  [ItemType.WEBPAGE]:              'Web Page',
  [ItemType.NOTE]:                 'Note',
  [ItemType.ATTACHMENT]:           'Attachment',
  [ItemType.ANNOTATION]:           'Annotation',
  [ItemType.ARTWORK]:              'Artwork',
  [ItemType.BLOG_POST]:            'Blog Post',
  [ItemType.DOCUMENT]:             'Document',
  [ItemType.INTERVIEW]:            'Interview',
  [ItemType.LETTER]:               'Letter',
  [ItemType.MAGAZINE_ARTICLE]:     'Magazine Article',
  [ItemType.MANUSCRIPT]:           'Manuscript',
  [ItemType.MAP]:                  'Map',
  [ItemType.NEWSPAPER_ARTICLE]:    'Newspaper Article',
  [ItemType.PATENT]:               'Patent',
  [ItemType.PODCAST]:              'Podcast',
  [ItemType.PREPRINT]:             'Preprint',
  [ItemType.PRESENTATION]:         'Presentation',
  [ItemType.SOFTWARE]:             'Software',
  [ItemType.VIDEO_RECORDING]:      'Video Recording',
  [ItemType.AUDIO_RECORDING]:      'Audio Recording',
  [ItemType.BILL]:                 'Bill',
  [ItemType.CASE]:                 'Case',
  [ItemType.COMPUTER_PROGRAM]:     'Computer Program',
  [ItemType.DICTIONARY_ENTRY]:     'Dictionary Entry',
  [ItemType.EMAIL]:                'Email',
  [ItemType.ENCYCLOPEDIA_ARTICLE]: 'Encyclopedia Article',
  [ItemType.FILM]:                 'Film',
  [ItemType.FORUM_POST]:           'Forum Post',
  [ItemType.HEARING]:              'Hearing',
  [ItemType.INSTANT_MESSAGE]:      'Instant Message',
  [ItemType.RADIO_BROADCAST]:      'Radio Broadcast',
  [ItemType.STATUTE]:              'Statute',
  [ItemType.TV_BROADCAST]:         'TV Broadcast',
};

@Component
export struct ItemTypeDropdown {
  @Prop selectedType: ItemType = ItemType.JOURNAL_ARTICLE;
  @Prop disabled: boolean = false;
  onChange?: (itemType: ItemType) => void;

  /** Get ordered list of main types for the dropdown. */
  private mainTypes(): ItemType[] {
    return [
      ItemType.JOURNAL_ARTICLE, ItemType.BOOK, ItemType.BOOK_SECTION,
      ItemType.CONFERENCE_PAPER, ItemType.THESIS, ItemType.REPORT,
      ItemType.WEBPAGE, ItemType.DOCUMENT, ItemType.PREPRINT,
      ItemType.PRESENTATION, ItemType.INTERVIEW, ItemType.LETTER,
      ItemType.MAGAZINE_ARTICLE, ItemType.NEWSPAPER_ARTICLE,
      ItemType.MANUSCRIPT, ItemType.MAP, ItemType.PATENT,
      ItemType.PODCAST, ItemType.SOFTWARE, ItemType.VIDEO_RECORDING,
      ItemType.AUDIO_RECORDING, ItemType.ARTWORK, ItemType.BLOG_POST,
      ItemType.FORUM_POST, ItemType.EMAIL, ItemType.INSTANT_MESSAGE,
      ItemType.ENCYCLOPEDIA_ARTICLE, ItemType.DICTIONARY_ENTRY,
      ItemType.FILM, ItemType.RADIO_BROADCAST, ItemType.TV_BROADCAST,
      ItemType.BILL, ItemType.CASE, ItemType.HEARING, ItemType.STATUTE,
      ItemType.COMPUTER_PROGRAM,
    ];
  }

  build() {
    Row() {
      Text(ITEM_TYPE_LABELS[this.selectedType] ?? this.selectedType)
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#222222')
        .layoutWeight(1)

      if (!this.disabled) {
        // Simple tap-based cycling for now — full Select component in next iteration
        Text('▾')
          .fontSize(14)
          .fontColor('#999999')
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .border({ width: { bottom: 1 }, color: '#E0E0E0' })
    .onClick(() => {
      if (this.disabled || !this.onChange) { return; }
      // Cycle to next type (simplified; full Select with popup in Phase 5 Batch 3)
      let types = this.mainTypes();
      let idx = types.indexOf(this.selectedType);
      let next = types[(idx + 1) % types.length];
      this.onChange(next);
    })
  }
}
