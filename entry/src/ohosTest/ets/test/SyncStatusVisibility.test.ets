/*
 * Sync status visibility — pending sync query + row helper tests.
 * Unit tests run without DB. Integration tests require DevEco context.
 */

import { describe, it, expect } from '@ohos/hypium';
import { LibraryRepository, PendingSyncSummary } from '../../main/ets/database/LibraryRepository.ets';
import {
  ItemTreeRowModel, applyPendingSyncToRows,
} from '../../main/ets/ui/tree/ItemTree.ets';

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
      expect(rows[1].isPendingSync === false).assertTrue();
    });

    it('unknown key in map → ignored', (): void => {
      let rows = [makeRow('X')];
      applyPendingSyncToRows(rows, { 'Y': true });
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

    it('removeFromSyncQueue → key removed', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Cleared Item');
        await repo.removeFromSyncQueue(1, 'item', [key]);
        let map = await repo.getPendingSyncKeySet();
        expect(!(map[key] === true)).assertTrue();
      });
    });

    it('delete log → pending key set contains key', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.addToDeleteLog(1, 'item', ['DEL_PEND_KEY']);
        let map = await repo.getPendingSyncKeySet();
        expect(map['DEL_PEND_KEY'] === true).assertTrue();
        await repo.removeFromDeleteLog(1, 'item', ['DEL_PEND_KEY']);
      });
    });

    it('summary counts by objectType', async (): Promise<void> => {
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

    it('isObjectPendingSync → true for queued item', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.addToSyncQueue(1, 'item', ['CHK_KEY']);
        expect(await repo.isObjectPendingSync(1, 'item', 'CHK_KEY')).assertTrue();
        await repo.removeFromSyncQueue(1, 'item', ['CHK_KEY']);
      });
    });

  });
}
