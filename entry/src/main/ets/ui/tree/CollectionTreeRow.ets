/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: xpcom/collectionTreeRow.js — row data model for collection tree
 *
 * ***** END LICENSE BLOCK *****
 */

/** Row type determines icon + behaviour. Ref: collectionTreeRow.js:73-85 */
export type CollectionRowType =
  | 'library' | 'group' | 'collection'
  | 'search' | 'feed' | 'duplicates'
  | 'unfiled' | 'trash' | 'publications' | 'retracted';

/** One row in the collection tree. */
export interface CollectionTreeRow {
  id: string;                // e.g. "C42", "L1"
  type: CollectionRowType;
  name: string;
  level: number;             // indentation depth
  isOpen: boolean;           // expanded or collapsed
  hasChildren: boolean;      // has subcollections or items
  libraryID: number;
  key?: string;              // API key (collections/searches)
  parentRowID?: string;      // parent row for local tree visibility
}

/** Build a unique tree ID. Ref: collectionTreeRow.js:72-83 */
export function makeRowID(type: CollectionRowType, refID: number | string): string {
  switch (type) {
    case 'library': case 'group': case 'feed':
      return `L${refID}`;
    case 'collection':
      return `C${refID}`;
    case 'search':
      return `S${refID}`;
    default:
      return `${type}-${refID}`;
  }
}

/** Icon character per row type (emoji placeholder — replace with actual icons). */
export function rowIcon(type: CollectionRowType, isOpen: boolean): string {
  switch (type) {
    case 'library':      return '📚';
    case 'group':        return '👥';
    case 'collection':   return isOpen ? '📂' : '📁';
    case 'search':       return '🔍';
    case 'feed':         return '📡';
    case 'duplicates':   return '🔄';
    case 'unfiled':      return '📋';
    case 'trash':        return '🗑';
    case 'publications': return '📖';
    case 'retracted':    return '⚠️';
    default:             return '•';
  }
}

/** Build initial rows for a library. Mock data — real data from API. */
export function buildDefaultRows(): CollectionTreeRow[] {
  return [
    { id: 'L1', type: 'library', name: 'My Library', level: 0, isOpen: true, hasChildren: true, libraryID: 1 },
    { id: 'C1', type: 'collection', name: 'Research Papers', level: 1, isOpen: false, hasChildren: false, libraryID: 1, key: 'C1' },
    { id: 'C2', type: 'collection', name: 'Coursework', level: 1, isOpen: false, hasChildren: true, libraryID: 1, key: 'C2' },
    { id: 'C3', type: 'collection', name: '  Seminar Notes', level: 2, isOpen: false, hasChildren: false, libraryID: 1, key: 'C3' },
    { id: 'search-1', type: 'search', name: 'Recent Additions', level: 1, isOpen: false, hasChildren: false, libraryID: 1 },
    { id: 'dupe-1', type: 'duplicates', name: 'Duplicate Items', level: 1, isOpen: false, hasChildren: false, libraryID: 1 },
    { id: 'unfiled-1', type: 'unfiled', name: 'Unfiled Items', level: 1, isOpen: false, hasChildren: false, libraryID: 1 },
    { id: 'trash-1', type: 'trash', name: 'Trash', level: 1, isOpen: false, hasChildren: false, libraryID: 1 },
  ];
}
