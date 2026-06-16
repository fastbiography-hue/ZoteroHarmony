/*
 * ItemTree hierarchy — buildItemTreeRows / listChildRowsForItems / helpers tests.
 * Unit tests (without DB) run always.
 * Integration tests (with DB) require DevEco context and skip gracefully.
 */

import { describe, it, expect } from '@ohos/hypium';
import { ItemModel } from '../../main/ets/model/ItemModel.ets';
import { ItemTreeRowModel } from '../../main/ets/ui/tree/ItemTree.ets';
import {
  buildItemTreeRows,
  collectParentKeysForChildLookup,
} from '../../main/ets/ui/helpers/ItemTreeRowHelpers.ets';
import { LibraryRepository, ItemChildSummary } from '../../main/ets/database/LibraryRepository.ets';

async function tryOpenRepo(): Promise<LibraryRepository | null> {
  try {
    let context = getContext().getApplicationContext();
    let repo = new LibraryRepository();
    await repo.open(context);
    return repo;
  } catch (err) {
    console.warn('[ItemTreeHierarchyTest] Cannot open DB — skipping: ' +
      (err as Error).message);
    return null;
  }
}

async function withRepo(body: (repo: LibraryRepository) => Promise<void>): Promise<void> {
  let repo = await tryOpenRepo();
  if (repo === null) { return; }
  try { await body(repo); }
  finally { await repo.close(); }
}

function makeItem(key: string, title: string, itemType: string): ItemModel {
  let item = new ItemModel();
  item.key = key;
  item.itemData.set('title', title);
  item.itemData.set('itemType', itemType);
  return item;
}

function makeChild(key: string, parentKey: string, childType: 'attachment' | 'note' | 'annotation', title: string, subtitle: string): ItemChildSummary {
  return { key, parentKey, childType, title, subtitle, sortIndex: '' };
}

export default function ItemTreeHierarchyTest(): void {
  describe('buildItemTreeRows + collectParentKeysForChildLookup (unit)', (): void => {

    // ================================================================
    // Test 1: collapsed parent — still shows isExpandable + childCount
    // ================================================================
    it('1) collapsed parent → isExpandable=true, childCount>0, no child rows', (): void => {
      let items = [makeItem('K1', 'Parent', 'journalArticle')];
      let children = [makeChild('A1', 'K1', 'attachment', 'paper.pdf', 'pdf')];
      let rows = buildItemTreeRows(items, children, []);
      expect(rows.length === 1).assertTrue();
      expect(rows[0].rowType === 'item').assertTrue();
      expect(rows[0].isExpandable === true).assertTrue();
      expect(rows[0].childCount === 1).assertTrue();
      expect(rows[0].isExpanded === false).assertTrue();
    });

    // ================================================================
    // Test 2: expanded parent — shows parent + children
    // ================================================================
    it('2) expanded parent → parent + child rows, isExpandable=true, isExpanded=true', (): void => {
      let items = [makeItem('K1', 'Parent', 'journalArticle')];
      let children = [
        makeChild('A1', 'K1', 'attachment', 'paper.pdf', 'pdf'),
        makeChild('N1', 'K1', 'note', 'My Note', ''),
      ];
      let rows = buildItemTreeRows(items, children, ['K1']);
      expect(rows.length === 3).assertTrue();
      expect(rows[0].isExpandable === true).assertTrue();
      expect(rows[0].isExpanded === true).assertTrue();
      expect(rows[1].rowType === 'attachment').assertTrue();
      expect(rows[1].level === 1).assertTrue();
      expect(rows[2].rowType === 'note').assertTrue();
      expect(rows[2].level === 1).assertTrue();
    });

    // ================================================================
    // Test 3: multiple parents — K1 with children, K2 without
    // ================================================================
    it('3) multiple parents → K1.isExpandable=true, K2.isExpandable=false', (): void => {
      let items = [
        makeItem('K1', 'Has Child', 'journalArticle'),
        makeItem('K2', 'No Child', 'book'),
      ];
      let children = [makeChild('A1', 'K1', 'attachment', 'file.pdf', 'pdf')];
      let rows = buildItemTreeRows(items, children, []);
      expect(rows.length === 2).assertTrue();
      let r1 = rows.find((r: ItemTreeRowModel) => r.key === 'K1');
      let r2 = rows.find((r: ItemTreeRowModel) => r.key === 'K2');
      expect(r1 !== undefined).assertTrue();
      expect(r2 !== undefined).assertTrue();
      if (r1) { expect(r1.isExpandable === true).assertTrue(); }
      if (r2) { expect(r2.isExpandable === false).assertTrue(); }
    });

    // ================================================================
    // Test 4: collectParentKeysForChildLookup — returns ALL keys
    // ================================================================
    it('4) collectParentKeysForChildLookup → returns all parent keys, not just expanded', (): void => {
      let items = [
        makeItem('K1', 'Item 1', 'journalArticle'),
        makeItem('K2', 'Item 2', 'book'),
        makeItem('K3', 'Item 3', 'conferencePaper'),
      ];
      let keys = collectParentKeysForChildLookup(items);
      expect(keys.length === 3).assertTrue();
      expect(keys.indexOf('K1') >= 0).assertTrue();
      expect(keys.indexOf('K2') >= 0).assertTrue();
      expect(keys.indexOf('K3') >= 0).assertTrue();
    });

    // ================================================================
    // Test 5: item without key → skipped
    // ================================================================
    it('5) collectParentKeysForChildLookup → skips null keys', (): void => {
      let items = [makeItem('K1', 'Has Key', 'journalArticle'), new ItemModel()];
      let keys = collectParentKeysForChildLookup(items);
      expect(keys.length === 1).assertTrue();
      expect(keys[0] === 'K1').assertTrue();
    });

    // ================================================================
    // Test 6: toggle expand/collapse rebuild
    // ================================================================
    it('6) toggle → collapsed→expanded shows children, expanded→collapsed hides them', (): void => {
      let items = [makeItem('K1', 'Toggle', 'journalArticle')];
      let children = [makeChild('A1', 'K1', 'attachment', 'f.pdf', 'pdf')];
      let collapsed = buildItemTreeRows(items, children, []);
      expect(collapsed.length === 1).assertTrue();
      let expanded = buildItemTreeRows(items, children, ['K1']);
      expect(expanded.length === 2).assertTrue();
    });

    // ================================================================
    // Test 7: empty items → empty rows
    // ================================================================
    it('7) empty items → empty rows', (): void => {
      let rows = buildItemTreeRows([], [makeChild('A1', 'K1', 'attachment', 'f.pdf', 'pdf')], ['K1']);
      expect(rows.length === 0).assertTrue();
    });

  });

  describe('listChildRowsForItems (integration)', (): void => {

    it('attachment child row → key + parentKey + title', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let pKey = await repo.createItem(null, 'journalArticle', 'Parent A');
        await repo.createLinkedUrlAttachment(pKey, 'https://example.com/paper.pdf');
        let rows = await repo.listChildRowsForItems([pKey]);
        let att = rows.find((r: ItemChildSummary) => r.childType === 'attachment');
        expect(att !== undefined).assertTrue();
        if (att) {
          expect(att.parentKey === pKey).assertTrue();
          expect(att.key.length > 0).assertTrue();
        }
      });
    });

    it('note child row → key + parentKey', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let pKey = await repo.createItem(null, 'journalArticle', 'Parent N');
        let nKey = await repo.createNote(pKey, 'Note Title', '<p>Body</p>');
        let rows = await repo.listChildRowsForItems([pKey]);
        let note = rows.find((r: ItemChildSummary) => r.childType === 'note');
        expect(note !== undefined).assertTrue();
        if (note) {
          expect(note.parentKey === pKey).assertTrue();
          expect(note.key === nKey).assertTrue();
        }
      });
    });

    it('deleted child → excluded', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let pKey = await repo.createItem(null, 'journalArticle', 'Parent Del');
        let nKey = await repo.createNote(pKey, 'Delete Me', '<p>gone</p>');
        await repo.deleteNote(Number.parseInt(
          (await repo.getItemByKey(nKey))?.id?.toString() ?? '0', 10));
        let rows = await repo.listChildRowsForItems([pKey]);
        expect(rows.find((r: ItemChildSummary) => r.key === nKey) === undefined).assertTrue();
      });
    });

    it('empty input → empty result', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let rows = await repo.listChildRowsForItems([]);
        expect(rows.length === 0).assertTrue();
      });
    });

  });
}
