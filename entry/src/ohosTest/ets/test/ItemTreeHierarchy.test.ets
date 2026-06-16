/*
 * ItemTree hierarchy — buildItemTreeRows + listChildRowsForItems tests.
 * Unit tests (buildItemTreeRows) run without DB.
 * Integration tests (listChildRowsForItems) require DevEco context.
 */

import { describe, it, expect } from '@ohos/hypium';
import { ItemModel } from '../../main/ets/model/ItemModel.ets';
import {
  ItemTreeRowModel,
  buildItemTreeRows,
} from '../../main/ets/ui/tree/ItemTree.ets';
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
  describe('buildItemTreeRows (unit)', (): void => {

    it('collapsed parent → only parent row, no children', (): void => {
      let items = [makeItem('K1', 'Parent Item', 'journalArticle')];
      let children = [makeChild('A1', 'K1', 'attachment', 'paper.pdf', 'application/pdf')];
      let rows = buildItemTreeRows(items, children, []);
      expect(rows.length === 1).assertTrue();
      expect(rows[0].rowType === 'item').assertTrue();
      expect(rows[0].key === 'K1').assertTrue();
    });

    it('expanded parent → parent + child rows', (): void => {
      let items = [makeItem('K1', 'Parent Item', 'journalArticle')];
      let children = [
        makeChild('A1', 'K1', 'attachment', 'paper.pdf', 'application/pdf'),
        makeChild('N1', 'K1', 'note', 'My Note', '2024-06-01'),
      ];
      let rows = buildItemTreeRows(items, children, ['K1']);
      expect(rows.length === 3).assertTrue();
      expect(rows[0].rowType === 'item').assertTrue();
      expect(rows[1].rowType === 'attachment').assertTrue();
      expect(rows[1].level === 1).assertTrue();
      expect(rows[2].rowType === 'note').assertTrue();
      expect(rows[2].level === 1).assertTrue();
    });

    it('child rows follow parent, no global sorting of children', (): void => {
      let items = [
        makeItem('K1', 'Alpha', 'journalArticle'),
        makeItem('K2', 'Beta', 'book'),
      ];
      let children = [makeChild('N2', 'K2', 'note', 'Beta Note', '')];
      let rows = buildItemTreeRows(items, children, ['K2']);
      // K1 first, K2 second, then K2's note
      expect(rows.length === 3).assertTrue();
      expect(rows[0].key === 'K1').assertTrue();
      expect(rows[1].key === 'K2').assertTrue();
      expect(rows[2].key === 'N2').assertTrue();
      expect(rows[2].parentKey === 'K2').assertTrue();
    });

    it('empty items → empty rows', (): void => {
      let rows = buildItemTreeRows([], [], []);
      expect(rows.length === 0).assertTrue();
    });

    it('item without key is skipped', (): void => {
      let item = new ItemModel();
      // key is null by default
      let rows = buildItemTreeRows([item], [], []);
      expect(rows.length === 0).assertTrue();
    });

    it('expanded state toggles correctly via rebuild', (): void => {
      let items = [makeItem('K1', 'Toggle Test', 'journalArticle')];
      let children = [makeChild('A1', 'K1', 'attachment', 'file.pdf', 'pdf')];
      // collapsed
      let r1 = buildItemTreeRows(items, children, []);
      expect(r1.length === 1).assertTrue();
      // expanded
      let r2 = buildItemTreeRows(items, children, ['K1']);
      expect(r2.length === 2).assertTrue();
    });

  });

  describe('listChildRowsForItems (integration)', (): void => {

    it('parent with attachment → returns attachment child row', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let pKey = await repo.createItem(null, 'journalArticle', 'Parent with attachment');
        await repo.createLinkedUrlAttachment(pKey, 'https://example.com/paper.pdf');
        let rows = await repo.listChildRowsForItems([pKey]);
        expect(rows.length >= 1).assertTrue();
        let att = rows.find((r: ItemChildSummary) => r.childType === 'attachment');
        expect(att !== undefined).assertTrue();
        if (att) {
          expect(att.parentKey === pKey).assertTrue();
          expect(att.key.length > 0).assertTrue();
        }
      });
    });

    it('parent with note → returns note child row', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let pKey = await repo.createItem(null, 'journalArticle', 'Parent with note');
        let nKey = await repo.createNote(pKey, 'Test Note', '<p>Body</p>');
        let rows = await repo.listChildRowsForItems([pKey]);
        let note = rows.find((r: ItemChildSummary) => r.childType === 'note');
        expect(note !== undefined).assertTrue();
        if (note) {
          expect(note.parentKey === pKey).assertTrue();
          expect(note.key === nKey).assertTrue();
        }
      });
    });

    it('deleted child item not returned', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let pKey = await repo.createItem(null, 'journalArticle', 'Parent for delete test');
        let nKey = await repo.createNote(pKey, 'Delete Me', '<p>gone</p>');
        await repo.deleteNote(
          Number.parseInt(
            (await repo.getItemByKey(nKey))?.id?.toString() ?? '0', 10
          )
        );
        let rows = await repo.listChildRowsForItems([pKey]);
        let found = rows.find((r: ItemChildSummary) => r.key === nKey);
        expect(found === undefined).assertTrue();
      });
    });

    it('empty parentKeys → empty result', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let rows = await repo.listChildRowsForItems([]);
        expect(rows.length === 0).assertTrue();
      });
    });

  });
}
