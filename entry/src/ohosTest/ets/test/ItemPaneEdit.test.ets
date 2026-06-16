/*
 * ItemPane edit closure — Repository update API tests.
 * Requires DevEco relationalStore context.
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
    console.warn('[ItemPaneEditTest] Cannot open DB — skipping: ' +
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

export default function ItemPaneEditTest(): void {
  describe('Repository update APIs for ItemPane edit', (): void => {

    // ================================================================
    // Test 1: updateItemField → value changed + syncQueue
    // ================================================================
    it('1) updateItemField → DOI updated + syncQueue contains key', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'DOI Test');
        await repo.removeFromSyncQueue(1, 'item', [key]);
        await repo.updateItemField(key, 'DOI', '10.1234/edit.test');
        let item = await repo.getItemByKey(key);
        expect(item !== null).assertTrue();
        if (item) {
          expect(item.itemData.get('DOI') === '10.1234/edit.test').assertTrue();
        }
        let queue = await repo.getAllObjectsInQueue(1, 'item');
        expect(queue.indexOf(key) >= 0).assertTrue();
      });
    });

    // ================================================================
    // Test 2: updateItemField empty → field deleted
    // ================================================================
    it('2) updateItemField empty value → field deleted from itemData + upload JSON', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Empty DOI Test');
        await repo.updateItemField(key, 'DOI', '10.1234/will.be.deleted');
        await repo.removeFromSyncQueue(1, 'item', [key]);
        // Now delete it
        await repo.updateItemField(key, 'DOI', '');
        let item = await repo.getItemByKey(key);
        expect(item !== null).assertTrue();
        if (item) {
          expect(item.itemData.get('DOI') === '' || item.itemData.get('DOI') === undefined).assertTrue();
        }
        let objects = await repo.getObjectsForUpload(1, 'item', [key]);
        expect(objects.length === 1).assertTrue();
        expect(objects[0]['DOI'] === '' || objectHasNoField(objects[0], 'DOI')).assertTrue();
        let queue = await repo.getAllObjectsInQueue(1, 'item');
        expect(queue.indexOf(key) >= 0).assertTrue();
      });
    });

    // ================================================================
    // Test 3: updateItemTypeByKey → type changed
    // ================================================================
    it('3) updateItemTypeByKey → itemType changed in itemData + upload JSON', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Type Change Test');
        await repo.removeFromSyncQueue(1, 'item', [key]);
        await repo.updateItemTypeByKey(key, 'book');
        let item = await repo.getItemByKey(key);
        expect(item !== null).assertTrue();
        if (item) {
          expect(item.itemData.get('itemType') === 'book').assertTrue();
        }
        let objects = await repo.getObjectsForUpload(1, 'item', [key]);
        expect(objects.length === 1).assertTrue();
        expect(objects[0]['itemType'] === 'book').assertTrue();
        let queue = await repo.getAllObjectsInQueue(1, 'item');
        expect(queue.indexOf(key) >= 0).assertTrue();
      });
    });

    // ================================================================
    // Test 4: note update → note + syncQueue
    // ================================================================
    it('4) updateNote → title/note updated + syncQueue contains note key', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let parentKey = await repo.createItem(null, 'journalArticle', 'Note Update Parent');
        let noteKey = await repo.createNote(parentKey, 'Old Title', '<p>Old</p>');
        await repo.removeFromSyncQueue(1, 'item', [noteKey]);
        // updateNote uses noteID, need itemID
        let noteItem = await repo.getItemByKey(noteKey);
        if (noteItem && noteItem.id) {
          await repo.updateNote(noteItem.id, 'Updated Title', '<p>Updated body</p>');
          let refreshed = await repo.getItemByKey(noteKey);
          expect(refreshed !== null).assertTrue();
          // Note body isn't in itemData — check upload JSON
          let objects = await repo.getObjectsForUpload(1, 'item', [noteKey]);
          expect(objects.length === 1).assertTrue();
          expect(objects[0]['note'] === '<p>Updated body</p>').assertTrue();
          let queue = await repo.getAllObjectsInQueue(1, 'item');
          expect(queue.indexOf(noteKey) >= 0).assertTrue();
        }
      });
    });

    // ================================================================
    // Test 5: remote upsert → no queue, then local edit → queue
    // ================================================================
    it('5) remote upsert → no queue; local edit → queue appears', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.upsertRemoteObject('item', {
          key: 'REMOTE_EDIT_TEST', version: 1,
          data: { itemType: 'journalArticle', title: 'Remote Edit Test' }
        });
        let qBefore = await repo.getAllObjectsInQueue(1, 'item');
        expect(qBefore.indexOf('REMOTE_EDIT_TEST') < 0).assertTrue();
        // Local edit
        await repo.updateItemField('REMOTE_EDIT_TEST', 'DOI', '10.9999/local.edit');
        let qAfter = await repo.getAllObjectsInQueue(1, 'item');
        expect(qAfter.indexOf('REMOTE_EDIT_TEST') >= 0).assertTrue();
      });
    });

    // ================================================================
    // Test 6: tag edit → syncQueue
    // ================================================================
    it('6) replaceItemTags → syncQueue contains item key', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Tag Sync Test');
        await repo.removeFromSyncQueue(1, 'item', [key]);
        await repo.replaceItemTags(key, [{ tag: 'edited-tag', type: 0 }]);
        let queue = await repo.getAllObjectsInQueue(1, 'item');
        expect(queue.indexOf(key) >= 0).assertTrue();
      });
    });

  });
}

function objectHasNoField(obj: Record<string, Object>, field: string): boolean {
  return !(field in obj) || obj[field] === undefined || obj[field] === '';
}
