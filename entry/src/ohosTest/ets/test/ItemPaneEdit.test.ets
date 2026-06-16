/*
 * ItemPane edit closure — Repository update API tests.
 * Requires DevEco relationalStore context. Skips gracefully without it.
 */

import { describe, it, expect } from '@ohos/hypium';
import { LibraryRepository } from '../../main/ets/database/LibraryRepository.ets';
import { ZoteroCreator } from '../../main/ets/model/ItemTypes.ets';
import { creatorsToJson, creatorsJsonEqual } from '../../main/ets/ui/ItemDetailsForm.ets';

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
  describe('creatorsToJson / creatorsJsonEqual (unit)', (): void => {

    it('creatorsJsonEqual → true for identical creators', (): void => {
      let a: ZoteroCreator[] = [
        { creatorType: 'author', firstName: 'Ada', lastName: 'Lovelace', fieldMode: 0 }
      ];
      let json = creatorsToJson(a);
      expect(creatorsJsonEqual(json, a)).assertTrue();
    });

    it('creatorsJsonEqual → false when creator type differs', (): void => {
      let a: ZoteroCreator[] = [
        { creatorType: 'author', firstName: 'A', lastName: 'B', fieldMode: 0 }
      ];
      let json = creatorsToJson(a);
      let b: ZoteroCreator[] = [
        { creatorType: 'editor', firstName: 'A', lastName: 'B', fieldMode: 0 }
      ];
      expect(!creatorsJsonEqual(json, b)).assertTrue();
    });

    it('creatorsJsonEqual → false when count differs', (): void => {
      let a: ZoteroCreator[] = [
        { creatorType: 'author', firstName: 'A', lastName: 'B', fieldMode: 0 }
      ];
      let json = creatorsToJson(a);
      expect(!creatorsJsonEqual(json, [])).assertTrue();
    });

  });

  describe('Repository update APIs (integration)', (): void => {

    // ================================================================
    // Test 1: updateItemField + syncQueue
    // ================================================================
    it('1) updateItemField → value changed + syncQueue', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Field Test');
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
    // Test 2: updateItemField empty → deleted
    // ================================================================
    it('2) updateItemField empty → field deleted from itemData', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Empty Test');
        await repo.updateItemField(key, 'DOI', '10.1234/to.delete');
        await repo.removeFromSyncQueue(1, 'item', [key]);
        await repo.updateItemField(key, 'DOI', '');
        let item = await repo.getItemByKey(key);
        let hasField = item !== null && (item!.itemData.get('DOI') ?? '').length > 0;
        expect(!hasField).assertTrue();
      });
    });

    // ================================================================
    // Test 3: updateItemType unsupported → no change
    // ================================================================
    it('3) updateItemTypeByKey unsupported type → no change', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Type Safety Test');
        await repo.removeFromSyncQueue(1, 'item', [key]);
        await repo.updateItemTypeByKey(key, 'notARealType');
        let item = await repo.getItemByKey(key);
        expect(item !== null).assertTrue();
        if (item) {
          // itemType should still be journalArticle
          expect(item.itemData.get('itemType') === 'journalArticle').assertTrue();
        }
        // Should not enter syncQueue (no mutation occurred)
        let queue = await repo.getAllObjectsInQueue(1, 'item');
        expect(queue.indexOf(key) < 0).assertTrue();
      });
    });

    // ================================================================
    // Test 4: updateItemCreatorsByKey → creator written
    // ================================================================
    it('4) updateItemCreatorsByKey → creator in upload JSON + syncQueue', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Creator Test');
        await repo.removeFromSyncQueue(1, 'item', [key]);
        await repo.updateItemCreatorsByKey(key, [
          { creatorType: 'author', firstName: 'Ada', lastName: 'Lovelace', fieldMode: 0 }
        ]);
        let objects = await repo.getObjectsForUpload(1, 'item', [key]);
        expect(objects.length === 1).assertTrue();
        let creators = objects[0]['creators'] as Record<string, Object>[];
        expect(creators.length === 1).assertTrue();
        expect(creators[0]['lastName'] === 'Lovelace').assertTrue();
        let queue = await repo.getAllObjectsInQueue(1, 'item');
        expect(queue.indexOf(key) >= 0).assertTrue();
      });
    });

    // ================================================================
    // Test 5: updateItemCreatorsByKey replace old
    // ================================================================
    it('5) updateItemCreatorsByKey replace → only new creator, old gone', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Replace Test');
        await repo.updateItemCreatorsByKey(key, [
          { creatorType: 'author', firstName: 'Old', lastName: 'Creator', fieldMode: 0 }
        ]);
        await repo.updateItemCreatorsByKey(key, [
          { creatorType: 'editor', firstName: 'New', lastName: 'Editor', fieldMode: 0 }
        ]);
        let objects = await repo.getObjectsForUpload(1, 'item', [key]);
        let creators = objects[0]['creators'] as Record<string, Object>[];
        expect(creators.length === 1).assertTrue();
        expect(creators[0]['lastName'] === 'Editor').assertTrue();
      });
    });

    // ================================================================
    // Test 6: updateItemCreatorsByKey empty → no creators
    // ================================================================
    it('6) updateItemCreatorsByKey empty → creators absent', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Empty Creator Test');
        await repo.updateItemCreatorsByKey(key, [
          { creatorType: 'author', firstName: 'Temp', lastName: 'Person', fieldMode: 0 }
        ]);
        await repo.updateItemCreatorsByKey(key, []);
        let objects = await repo.getObjectsForUpload(1, 'item', [key]);
        expect(objects.length === 1).assertTrue();
        let hasCreators = objects[0]['creators'] !== undefined;
        expect(!hasCreators).assertTrue();
      });
    });

    // ================================================================
    // Test 7: remote → no queue; local edit → queue
    // ================================================================
    it('7) remote upsert → no queue; local edit → queue', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.upsertRemoteObject('item', {
          key: 'REMOTE_EDIT_7', version: 1,
          data: { itemType: 'journalArticle', title: 'Remote then Local' }
        });
        let qBefore = await repo.getAllObjectsInQueue(1, 'item');
        expect(qBefore.indexOf('REMOTE_EDIT_7') < 0).assertTrue();
        await repo.updateItemField('REMOTE_EDIT_7', 'DOI', '10.9999/local');
        let qAfter = await repo.getAllObjectsInQueue(1, 'item');
        expect(qAfter.indexOf('REMOTE_EDIT_7') >= 0).assertTrue();
      });
    });

  });
}
