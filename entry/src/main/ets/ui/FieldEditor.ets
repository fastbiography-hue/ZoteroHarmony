/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ported from Zotero Desktop (AGPL-3.0)
 * Ref: elements/itemBox.js — single field value editor
 *
 * ***** END LICENSE BLOCK *****
 */

/** Human-readable labels for CSL fields. */
const FIELD_LABELS: Record<string, string> = {
  'title':            'Title',
  'abstractNote':     'Abstract',
  'date':             'Date',
  'DOI':              'DOI',
  'ISBN':             'ISBN',
  'ISSN':             'ISSN',
  'url':              'URL',
  'accessDate':       'Accessed',
  'extra':            'Extra',
  'pages':            'Pages',
  'volume':           'Volume',
  'issue':            'Issue',
  'series':           'Series',
  'seriesTitle':      'Series Title',
  'publicationTitle': 'Publication',
  'publisher':        'Publisher',
  'place':            'Place',
  'edition':          'Edition',
  'language':         'Language',
  'shortTitle':       'Short Title',
  'callNumber':       'Call Number',
  'archive':          'Archive',
  'libraryCatalog':   'Library Catalog',
  'rights':           'Rights',
  'citationKey':      'Citation Key',
  'number':           'Number',
  'journalAbbreviation': 'Journal Abbr.',
};

/**
 * Single field editor — label row + value input.
 * Shows all fields even when empty (Zotero convention).
 */
@Component
export struct FieldEditor {
  @Prop fieldName: string = '';
  @Prop fieldValue: string = '';
  @Prop multiline: boolean = false;
  @Prop readOnly: boolean = false;
  onChange?: (value: string) => void;

  build() {
    Column() {
      // Label
      Text(FIELD_LABELS[this.fieldName] ?? this.fieldName)
        .fontSize(11)
        .fontColor('#888888')
        .fontWeight(FontWeight.Medium)
        .fontWeight(FontWeight.Bold)
        .padding({ left: 12, top: 8, bottom: 2 })

      // Value
      if (this.multiline) {
        TextArea({ text: this.fieldValue, placeholder: `Add ${this.fieldName}…` })
          .fontSize(15).height(100)
          .enabled(!this.readOnly)
          .onChange((value: string) => { if (this.onChange) { this.onChange(value); } })
          .padding({ left: 12, right: 12 })
      } else {
        TextInput({ text: this.fieldValue, placeholder: `Add ${this.fieldName}…` })
          .fontSize(15)
          .enabled(!this.readOnly)
          .onChange((value: string) => { if (this.onChange) { this.onChange(value); } })
          .padding({ left: 12, right: 12 })
      }
    }
    .width('100%')
  }
}
