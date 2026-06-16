/*
 * Pure helpers for ItemTree row model building and pending-sync flagging.
 * Extracted from ItemTree.ets so tests can import without pulling
 * in the @Component struct.
 */

import { ItemModel } from '../../model/ItemModel.ets';
import { ItemChildSummary } from '../../database/LibraryRepository.ets';
import { ItemTreeRowModel } from '../tree/ItemTree.ets';

/**
 * Build flattened tree rows from parent items and child summaries.
 * Pure function — does not access DB.
 */
export function buildItemTreeRows(
  items: ItemModel[],
  children: ItemChildSummary[],
  expandedKeys: string[]
): ItemTreeRowModel[] {
  let rows: ItemTreeRowModel[] = [];
  let childMap = new Map<string, ItemChildSummary[]>();
  for (let i = 0; i < children.length; i++) {
    let pk = children[i].parentKey;
    let list = childMap.get(pk) ?? [];
    list.push(children[i]);
    childMap.set(pk, list);
  }
  for (let i = 0; i < items.length; i++) {
    let item = items[i];
    let key = item.key ?? '';
    if (key.length === 0) {
      continue;
    }
    let childList = childMap.get(key) ?? [];
    let isExpanded = expandedKeys.indexOf(key) >= 0;
    let childCount = childList.length;
    let icon = _iconForItemType(item.itemData.get('itemType') ?? 'journalArticle');

    rows.push({
      id: `item-${key}`,
      key: key,
      rowType: 'item',
      level: 0,
      item: item,
      parentKey: '',
      title: item.displayTitle ?? item.itemData.get('title') ?? '(untitled)',
      subtitle: (item.itemData.get('creator') ?? item.itemData.get('date') ?? ''),
      icon: icon,
      isExpandable: childCount > 0,
      isExpanded: isExpanded,
      childCount: childCount,
      isPendingSync: false,
    });

    if (isExpanded && childList.length > 0) {
      for (let c = 0; c < childList.length; c++) {
        let child = childList[c];
        let subIcon = child.childType === 'attachment' ? 'A' :
          (child.childType === 'note' ? 'N' : 'H');
        rows.push({
          id: `child-${child.key}`,
          key: child.key,
          rowType: child.childType,
          level: 1,
          item: null,
          parentKey: key,
          title: child.title,
          subtitle: child.subtitle,
          icon: subIcon,
          isExpandable: false,
          isExpanded: false,
          childCount: 0,
          isPendingSync: false,
        });
      }
    }
  }
  return rows;
}

/**
 * Apply pending sync flags to rows from a pending key map.
 * Pure function — does not access DB.
 */
export function applyPendingSyncToRows(
  rows: ItemTreeRowModel[],
  pendingMap: Record<string, boolean>
): void {
  for (let i = 0; i < rows.length; i++) {
    rows[i].isPendingSync = pendingMap[rows[i].key] === true;
  }
}

/** Extract all non-empty parent keys from items for child lookups. */
export function collectParentKeysForChildLookup(items: ItemModel[]): string[] {
  let keys: string[] = [];
  for (let i = 0; i < items.length; i++) {
    let k = items[i].key ?? '';
    if (k.length > 0) { keys.push(k); }
  }
  return keys;
}

function _iconForItemType(itemType: string): string {
  let lower = itemType.toLowerCase();
  if (lower === 'book') { return 'B'; }
  if (lower === 'conferencepaper') { return 'C'; }
  if (lower === 'thesis') { return 'T'; }
  if (lower === 'report') { return 'R'; }
  if (lower === 'note') { return 'N'; }
  if (lower === 'attachment') { return 'A'; }
  if (lower === 'annotation') { return 'H'; }
  return 'J';
}
