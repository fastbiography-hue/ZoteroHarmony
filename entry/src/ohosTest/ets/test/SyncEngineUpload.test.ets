/*
 * SyncEngine upload pipeline integration tests.
 * Requires DevEco relationalStore context. Skips gracefully without it.
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
    console.warn('[SyncEngineUploadTest] Cannot open DB — skipping: ' +
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

export default function SyncEngineUploadTest(): void {
  describe('SyncEngine upload pipeline (LibraryRepository serialization)', (): void => {

    // ================================================================
    // Test 1: getObjectsForUpload — collection JSON
    // ================================================================
    it('1) getObjectsForUpload collection → name + parentCollection=false', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createCollection('Upload Col Test', null);
        let objects = await repo.getObjectsForUpload(1, 'collection', [key]);
        expect(objects.length === 1).assertTrue();
        let obj = objects[0];
        expect(obj['key'] === key).assertTrue();
        expect(obj['name'] === 'Upload Col Test').assertTrue();
        expect(obj['parentCollection'] === false).assertTrue();
      });
    });

    // ================================================================
    // Test 2: getObjectsForUpload — search JSON with conditions
    // ================================================================
    it('2) getObjectsForUpload search → name + conditions array', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createSavedSearch('Upload Search', [
          { condition: 'title', operator: 'contains', value: 'test', required: true },
        ]);
        let objects = await repo.getObjectsForUpload(1, 'search', [key]);
        expect(objects.length === 1).assertTrue();
        let obj = objects[0];
        expect(obj['name'] === 'Upload Search').assertTrue();
        let conds = obj['conditions'] as Record<string, Object>[];
        expect(conds.length === 1).assertTrue();
        expect(conds[0]['condition'] === 'title').assertTrue();
      });
    });

    // ================================================================
    // Test 3: getObjectsForUpload — item JSON with top-level fields
    // ================================================================
    it('3) getObjectsForUpload item → fields at top level (not extraFields)', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Upload Test Article');
        await repo.updateItemField(key, 'DOI', '10.9999/upload.test');
        await repo.replaceItemTags(key, [{ tag: 'upload-tag', type: 0 }]);
        let objects = await repo.getObjectsForUpload(1, 'item', [key]);
        expect(objects.length === 1).assertTrue();
        let obj = objects[0];
        expect(obj['itemType'] === 'journalArticle').assertTrue();
        expect(obj['title'] === 'Upload Test Article').assertTrue();
        expect(obj['DOI'] === '10.9999/upload.test').assertTrue();
        // tags at top level
        let tags = obj['tags'] as Record<string, Object>[];
        expect(tags.length >= 1).assertTrue();
        expect(tags[0]['tag'] === 'upload-tag').assertTrue();
      });
    });

    // ================================================================
    // Test 4: getObjectsForUpload — creators output
    // ================================================================
    it('4) getObjectsForUpload item → creators with firstName/lastName', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        // createItem doesn't set creators via API — use remote upsert to seed
        await repo.upsertRemoteObject('item', {
          key: 'ITEM_UPLOAD_CREATOR', version: 1,
          data: {
            itemType: 'book', title: 'Creator Upload Test',
            creators: [
              { creatorType: 'author', firstName: 'Alice', lastName: 'Smith' },
              { creatorType: 'editor', firstName: 'Bob', lastName: 'Jones' },
            ]
          }
        });
        let objects = await repo.getObjectsForUpload(1, 'item', ['ITEM_UPLOAD_CREATOR']);
        expect(objects.length === 1).assertTrue();
        let creators = objects[0]['creators'] as Record<string, Object>[];
        expect(creators.length === 2).assertTrue();
        expect(creators[0]['lastName'] === 'Smith').assertTrue();
      });
    });

    // ================================================================
    // Test 5: remote upsert key is NOT in syncQueue
    // ================================================================
    it('5) remote upsert key → not in syncQueue (no upload loop)', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.upsertRemoteObject('item', {
          key: 'REMOTE_NO_UPLOAD', version: 1,
          data: { itemType: 'journalArticle', title: 'Remote no upload' }
        });
        let queue = await repo.getAllObjectsInQueue(1, 'item');
        expect(queue.indexOf('REMOTE_NO_UPLOAD') < 0).assertTrue();
      });
    });

    // ================================================================
    // Test 6: delete log → getDeleted returns correct keys
    // ================================================================
    it('6) addToDeleteLog → getDeleted returns keys, removeFromDeleteLog clears', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.addToDeleteLog(1, 'item', ['DEL_KEY_TEST']);
        let deleted = await repo.getDeleted(1, 'item');
        expect(deleted.indexOf('DEL_KEY_TEST') >= 0).assertTrue();
        await repo.removeFromDeleteLog(1, 'item', ['DEL_KEY_TEST']);
        let after = await repo.getDeleted(1, 'item');
        expect(after.indexOf('DEL_KEY_TEST') < 0).assertTrue();
      });
    });

    // ================================================================
    // Test 7: getObjectsForUpload — note item
    // ================================================================
    it('7) getObjectsForUpload note → note + parentItem in output', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let parentKey = await repo.createItem(null, 'journalArticle', 'Note Parent');
        let noteKey = await repo.createNote(parentKey, 'Note Title', '<p>Body</p>');
        let objects = await repo.getObjectsForUpload(1, 'item', [noteKey]);
        expect(objects.length === 1).assertTrue();
        expect(objects[0]['itemType'] === 'note').assertTrue();
        expect(objects[0]['note'] === '<p>Body</p>').assertTrue();
        expect(objects[0]['parentItem'] === parentKey).assertTrue();
      });
    });

    // ================================================================
    // Test 8: getObjectsForUpload — attachment item
    // ================================================================
    it('8) getObjectsForUpload attachment → linkMode/contentType/path/parentItem', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let parentKey = await repo.createItem(null, 'journalArticle', 'Attachment Parent');
        await repo.upsertRemoteObject('item', {
          key: 'ATT_UPLOAD_TEST', version: 1,
          data: {
            itemType: 'attachment', linkMode: 'imported_file',
            contentType: 'application/pdf', path: '/test/upload.pdf',
            parentItem: parentKey,
          }
        });
        let objects = await repo.getObjectsForUpload(1, 'item', ['ATT_UPLOAD_TEST']);
        expect(objects.length === 1).assertTrue();
        expect(objects[0]['linkMode'] === 'imported_file').assertTrue();
        expect(objects[0]['contentType'] === 'application/pdf').assertTrue();
        expect(objects[0]['parentItem'] === parentKey).assertTrue();
      });
    });

    // ================================================================
    // Test 9: getObjectsForUpload — deleted/trash flag
    // ================================================================
    it('9) getObjectsForUpload → trash item has deleted=true', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Trash Upload Test');
        await repo.moveItemToTrash(key);
        let objects = await repo.getObjectsForUpload(1, 'item', [key]);
        expect(objects.length === 1).assertTrue();
        expect(objects[0]['deleted'] === true).assertTrue();
      });
    });

    // ================================================================
    // Test 10: empty keys → empty result
    // ================================================================
    it('10) getObjectsForUpload with empty keys → empty array', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let objects = await repo.getObjectsForUpload(1, 'item', []);
        expect(objects.length === 0).assertTrue();
      });
    });

  });
}
