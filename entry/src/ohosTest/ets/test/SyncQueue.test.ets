/*
 * Persistent syncQueue / syncDeleteLog integration tests.
 *
 * Requires: DevEco relationalStore context.
 * When context is unavailable, tests skip without failing.
 */

import { describe, it, expect } from '@ohos/hypium';
import { LibraryRepository } from '../../main/ets/database/LibraryRepository.ets';

async function tryOpenRepo(): Promise<LibraryRepository | null> {
  try {
    let context = getContext().getApplicationContext();
    let repo = new LibraryRepository();
    await repo.open(context);
    return repo;
  } catch (err) {
    console.warn('[SyncQueueTest] Cannot open DB — skipping: ' +
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

export default function SyncQueueTest(): void {
  describe('Persistent syncQueue / syncDeleteLog', (): void => {

    // ================================================================
    // Test 1: createCollection → syncQueue entry
    // ================================================================
    it('1) createCollection → sets synced=0 and enqueues', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createCollection('Sync Test Col', null);
        expect(key.length > 0).assertTrue();
        let queue = await repo.getAllObjectsInQueue(1, 'collection');
        expect(queue.indexOf(key) >= 0).assertTrue();
      });
    });

    // ================================================================
    // Test 2: renameCollection → enqueues
    // ================================================================
    it('2) renameCollection → enqueues collection key', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createCollection('Rename Me', null);
        // Clear the queue from the create so we test rename in isolation
        await repo.removeFromSyncQueue(1, 'collection', [key]);
        await repo.renameCollection(key, 'Renamed');
        let queue = await repo.getAllObjectsInQueue(1, 'collection');
        expect(queue.indexOf(key) >= 0).assertTrue();
      });
    });

    // ================================================================
    // Test 3: deleteCollection → deleteLog entry, queue cleared
    // ================================================================
    it('3) deleteCollection → deleteLog entry, syncQueue cleared', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createCollection('Delete Me', null);
        // There should be a syncQueue entry from create
        let queueBefore = await repo.getAllObjectsInQueue(1, 'collection');
        expect(queueBefore.indexOf(key) >= 0).assertTrue();
        await repo.deleteCollection(key);
        // syncQueue should be cleared (added by deleteLog → removeFromSyncQueue)
        // Note: createCollection already called addToSyncQueue.
        // deleteCollection calls addToDeleteLog which removes from syncQueue.
        let queueAfter = await repo.getAllObjectsInQueue(1, 'collection');
        expect(queueAfter.indexOf(key) < 0).assertTrue();
        let delLog = await repo.getDeleted(1, 'collection');
        expect(delLog.indexOf(key) >= 0).assertTrue();
      });
    });

    // ================================================================
    // Test 4: createItem → syncQueue
    // ================================================================
    it('4) createItem → syncQueue has item/key', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Queue Test Item');
        let queue = await repo.getAllObjectsInQueue(1, 'item');
        expect(queue.indexOf(key) >= 0).assertTrue();
      });
    });

    // ================================================================
    // Test 5: updateItemField → syncQueue
    // ================================================================
    it('5) updateItemField → syncQueue has item/key', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Update Field Test');
        await repo.removeFromSyncQueue(1, 'item', [key]);
        await repo.updateItemField(key, 'title', 'Updated Title');
        let queue = await repo.getAllObjectsInQueue(1, 'item');
        expect(queue.indexOf(key) >= 0).assertTrue();
      });
    });

    // ================================================================
    // Test 6: replaceItemTags → syncQueue
    // ================================================================
    it('6) replaceItemTags → syncQueue has item/key', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Tag Test Item');
        await repo.removeFromSyncQueue(1, 'item', [key]);
        await repo.replaceItemTags(key, [{ tag: 'newtag', type: 0 }]);
        let queue = await repo.getAllObjectsInQueue(1, 'item');
        expect(queue.indexOf(key) >= 0).assertTrue();
      });
    });

    // ================================================================
    // Test 7: createNote → syncQueue
    // ================================================================
    it('7) createNote → syncQueue has note item key', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let parentKey = await repo.createItem(null, 'journalArticle', 'Parent for note queue');
        await repo.removeFromSyncQueue(1, 'item', [parentKey]);
        let noteKey = await repo.createNote(parentKey, 'Note Title', 'Note body');
        let queue = await repo.getAllObjectsInQueue(1, 'item');
        expect(queue.indexOf(noteKey) >= 0).assertTrue();
      });
    });

    // ================================================================
    // Test 8: deleteNote → trash upsert (calls moveToTrash → addToSyncQueue)
    // ================================================================
    it('8) deleteNote → item upsert queued (trash=upsert strategy)', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let parentKey = await repo.createItem(null, 'journalArticle', 'Parent for delete note');
        let noteKey = await repo.createNote(parentKey, 'Del Note', 'Will be deleted');
        // Clear queue entries from creates
        await repo.removeFromSyncQueue(1, 'item', [parentKey, noteKey]);
        // deleteNote calls moveItemToTrash which calls addToSyncQueue
        await repo.deleteNote(
          Number.parseInt((await repo.getItemByKey(noteKey))?.id?.toString() ?? '0', 10)
        );
        let queue = await repo.getAllObjectsInQueue(1, 'item');
        expect(queue.indexOf(noteKey) >= 0).assertTrue();
      });
    });

    // ================================================================
    // Test 9: createSavedSearch → syncQueue
    // ================================================================
    it('9) createSavedSearch → syncQueue has search/key', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createSavedSearch('Queue Search', [
          { condition: 'title', operator: 'contains', value: 'test', required: true }
        ]);
        let queue = await repo.getAllObjectsInQueue(1, 'search');
        expect(queue.indexOf(key) >= 0).assertTrue();
      });
    });

    // ================================================================
    // Test 10: remote upsert does NOT enqueue
    // ================================================================
    it('10) remote upsert → syncQueue does NOT contain remote key', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.upsertRemoteObject('item', {
          key: 'REMOTE_K10', version: 1,
          data: { itemType: 'journalArticle', title: 'Remote Item' }
        });
        let queue = await repo.getAllObjectsInQueue(1, 'item');
        expect(queue.indexOf('REMOTE_K10') < 0).assertTrue();
        let delLog = await repo.getDeleted(1, 'item');
        expect(delLog.indexOf('REMOTE_K10') < 0).assertTrue();
      });
    });

    // ================================================================
    // Test 11: addToDeleteLog removes from syncQueue
    // ================================================================
    it('11) addToDeleteLog → removes key from syncQueue', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.addToSyncQueue(1, 'item', ['TEST_KEY_11']);
        let qBefore = await repo.getAllObjectsInQueue(1, 'item');
        expect(qBefore.indexOf('TEST_KEY_11') >= 0).assertTrue();
        await repo.addToDeleteLog(1, 'item', ['TEST_KEY_11']);
        let qAfter = await repo.getAllObjectsInQueue(1, 'item');
        expect(qAfter.indexOf('TEST_KEY_11') < 0).assertTrue();
      });
    });

  });
}
