/*
 * Sync status visibility — pending sync query + row helper tests.
 * Unit tests without DB. Integration tests require DevEco context.
 */

import { describe, it, expect } from '@ohos/hypium';
import { LibraryRepository, PendingSyncSummary } from '../../main/ets/database/LibraryRepository.ets';
import { ItemTreeRowModel } from '../../main/ets/ui/tree/ItemTree.ets';
import { applyPendingSyncToRows } from '../../main/ets/ui/helpers/ItemTreeRowHelpers.ets';

async function tryOpenRepo(): Promise<LibraryRepository | null> {
  try {
    let context = getContext().getApplicationContext();
    let repo = new LibraryRepository();
    await repo.open(context);
    return repo;
  } catch (err) {
    console.warn('[SyncStatusVisibilityTest] Cannot open DB — skipping: ' +
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

function makeRow(key: string): ItemTreeRowModel {
  return {
    id: `row-${key}`, key, rowType: 'item', level: 0,
    item: null, parentKey: '', title: key, subtitle: '',
    icon: 'J', isExpandable: false, isExpanded: false,
    childCount: 0, isPendingSync: false,
  };
}

export default function SyncStatusVisibilityTest(): void {
  describe('applyPendingSyncToRows (unit)', (): void => {

    it('pending map true → isPendingSync=true', (): void => {
      let rows = [makeRow('A'), makeRow('B')];
      applyPendingSyncToRows(rows, { 'A': true });
      expect(rows[0].isPendingSync === true).assertTrue();
      expect(rows[1].isPendingSync === false).assertTrue();
    });

    it('empty map → all false', (): void => {
      let rows = [makeRow('A'), makeRow('B')];
      applyPendingSyncToRows(rows, {});
      expect(rows[0].isPendingSync === false).assertTrue();
    });

    it('unknown key in map → ignored', (): void => {
      let rows = [makeRow('X')];
      applyPendingSyncToRows(rows, { 'Y': true });
      expect(rows[0].isPendingSync === false).assertTrue();
    });

    it('re-apply clears previously set flags', (): void => {
      let rows = [makeRow('A')];
      applyPendingSyncToRows(rows, { 'A': true });
      expect(rows[0].isPendingSync === true).assertTrue();
      applyPendingSyncToRows(rows, {});
      expect(rows[0].isPendingSync === false).assertTrue();
    });

  });

  describe('Pending sync queries (integration)', (): void => {

    it('empty → summary all zeros', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let s = await repo.getPendingSyncSummary();
        expect(s.queueCount === 0).assertTrue();
        expect(s.deleteCount === 0).assertTrue();
      });
    });

    it('create item → pending key set contains key', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Pending Item');
        let map = await repo.getPendingSyncKeySet();
        expect(map[key] === true).assertTrue();
      });
    });

    it('getPendingSyncKeySet item-only → excludes collection/search', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.addToSyncQueue(1, 'collection', ['COL_KEY']);
        await repo.addToSyncQueue(1, 'search', ['SEARCH_KEY']);
        await repo.addToSyncQueue(1, 'item', ['ITEM_KEY']);
        let map = await repo.getPendingSyncKeySet();
        expect(map['ITEM_KEY'] === true).assertTrue();
        expect(!(map['COL_KEY'] === true)).assertTrue();
        expect(!(map['SEARCH_KEY'] === true)).assertTrue();
        // cleanup
        await repo.removeFromSyncQueue(1, 'collection', ['COL_KEY']);
        await repo.removeFromSyncQueue(1, 'search', ['SEARCH_KEY']);
        await repo.removeFromSyncQueue(1, 'item', ['ITEM_KEY']);
      });
    });

    it('getPendingSyncKeySet item-only → deleteLog also item-only', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.addToDeleteLog(1, 'collection', ['COL_DEL']);
        await repo.addToDeleteLog(1, 'item', ['ITEM_DEL']);
        let map = await repo.getPendingSyncKeySet();
        expect(map['ITEM_DEL'] === true).assertTrue();
        expect(!(map['COL_DEL'] === true)).assertTrue();
        // cleanup
        await repo.removeFromDeleteLog(1, 'item', ['ITEM_DEL']);
        await repo.removeFromDeleteLog(1, 'collection', ['COL_DEL']);
      });
    });

    it('summary counts include collection/search', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.addToSyncQueue(1, 'item', ['I1']);
        await repo.addToSyncQueue(1, 'collection', ['C1']);
        await repo.addToDeleteLog(1, 'item', ['DI1']);
        let s = await repo.getPendingSyncSummary();
        expect(s.itemQueueCount >= 1).assertTrue();
        expect(s.collectionQueueCount >= 1).assertTrue();
        expect(s.itemDeleteCount >= 1).assertTrue();
        expect(s.queueCount >= 2).assertTrue();
        expect(s.deleteCount >= 1).assertTrue();
        // cleanup
        await repo.removeFromSyncQueue(1, 'item', ['I1']);
        await repo.removeFromSyncQueue(1, 'collection', ['C1']);
        await repo.removeFromDeleteLog(1, 'item', ['DI1']);
      });
    });

    it('removeFromSyncQueue → key removed from map', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Cleared Item');
        await repo.removeFromSyncQueue(1, 'item', [key]);
        let map = await repo.getPendingSyncKeySet();
        expect(!(map[key] === true)).assertTrue();
      });
    });

    it('delete log → pending key set contains key', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.addToDeleteLog(1, 'item', ['DEL_PEND']);
        let map = await repo.getPendingSyncKeySet();
        expect(map['DEL_PEND'] === true).assertTrue();
        await repo.removeFromDeleteLog(1, 'item', ['DEL_PEND']);
      });
    });

    it('isObjectPendingSync → true for queued item', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.addToSyncQueue(1, 'item', ['CHK']);
        expect(await repo.isObjectPendingSync(1, 'item', 'CHK')).assertTrue();
        await repo.removeFromSyncQueue(1, 'item', ['CHK']);
      });
    });

  });
}
