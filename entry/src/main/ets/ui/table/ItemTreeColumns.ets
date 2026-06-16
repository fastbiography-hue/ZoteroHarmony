/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: itemTreeColumns.jsx — column definitions for item tree
 *
 * ***** END LICENSE BLOCK *****
 */

import { ItemModel } from '../../model/ItemModel.ets';

/** Configuration for one column in the item tree. */
export interface ItemTreeColumn {
  dataKey: string;
  label: string;
  primary: boolean;
  flex: number;
  minWidth: number;
  sortable: boolean;
  /** Render a cell value for the given item. */
  render: (item: ItemModel) => string;
}

/** Item type → compact text icon for dense table rows. */
const ITEM_TYPE_ICONS: Record<string, string> = {
  'journalArticle':  'J',
  'book':            'B',
  'bookSection':     'S',
  'conferencePaper': 'C',
  'thesis':          'T',
  'report':          'R',
  'webpage':         'W',
  'note':            'N',
  'attachment':      'A',
  'annotation':      'M',
};

/**
 * Default column set — mirrors itemTreeColumns.jsx:61.
 */
export const DEFAULT_COLUMNS: ItemTreeColumn[] = [
  {
    dataKey: 'title', primary: true, label: 'Title',
    flex: 4, minWidth: 120, sortable: true,
    render: (item: ItemModel): string => {
      return item.displayTitle ?? item.itemData.get('title') ?? '(no title)';
    },
  },
  {
    dataKey: 'firstCreator', primary: false, label: 'Creator',
    flex: 1, minWidth: 80, sortable: true,
    render: (item: ItemModel): string => {
      let c = item.creators;
      if (c.length === 0) { return item.itemData.get('creator') ?? ''; }
      return c[0].lastName || c[0].firstName || '';
    },
  },
  {
    dataKey: 'itemType', primary: false, label: 'Type',
    flex: 1, minWidth: 60, sortable: true,
    render: (item: ItemModel): string => {
      let itemType = item.itemData.get('itemType') ?? '';
      if (itemType.length > 0) { return ITEM_TYPE_ICONS[itemType] ?? itemType.charAt(0).toUpperCase(); }
      return 'J';
    },
  },
  {
    dataKey: 'date', primary: false, label: 'Date',
    flex: 1, minWidth: 70, sortable: true,
    render: (item: ItemModel): string => {
      return item.itemData.get('date') ?? '';
    },
  },
  {
    dataKey: 'publisher', primary: false, label: 'Publisher',
    flex: 1, minWidth: 80, sortable: true,
    render: (item: ItemModel): string => {
      return item.itemData.get('publisher') ?? '';
    },
  },
  {
    dataKey: 'year', primary: false, label: 'Year',
    flex: 1, minWidth: 50, sortable: true,
    render: (item: ItemModel): string => {
      let d = item.itemData.get('date') ?? '';
      let m = d.match(/(\d{4})/);
      return m ? m[1] : '';
    },
  },
];
