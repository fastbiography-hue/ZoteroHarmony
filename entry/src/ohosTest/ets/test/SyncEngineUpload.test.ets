/*
 * SyncEngine upload pipeline tests.
 * Requires DevEco relationalStore context. Skips gracefully without it.
 *
 * Mix of:
 *   - Unit tests (no DB needed): extractObjectKeys, missingKeys cleanup
 *   - Integration tests (DB needed): annotation serialization, queue lifecycle
 */

import { describe, it, expect } from '@ohos/hypium';
import { LibraryRepository } from '../../main/ets/database/LibraryRepository.ets';
import { SyncEngine, SyncLibrary } from '../../main/ets/sync/SyncEngine.ets';
import { ZoteroAPI } from '../../main/ets/api/ZoteroAPI.ets';
import { ZoteroAPIUpload } from '../../main/ets/api/ZoteroAPIUpload.ets';
import { HttpClient } from '../../main/ets/api/HttpClient.ets';
import { SyncLocalState } from '../../main/ets/sync/SyncLocalState.ets';
import { UploadResult } from '../../main/ets/sync/SyncExceptions.ets';

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

/** Construct a real SyncEngine that can test _startUpload. */
function makeSyncEngine(appContext?: Context | null): SyncEngine {
  let http = new HttpClient('https://api.zotero.org');
  let lib: SyncLibrary = {
    libraryID: 1, libraryType: 'user', libraryTypeID: 1,
    libraryVersion: 0, storageVersion: 0, name: 'My Library',
  };
  return new SyncEngine(
    new ZoteroAPI(http),
    new ZoteroAPIUpload(http),
    lib,
    new SyncLocalState(),
    appContext ?? null,
  );
}

export default function SyncEngineUploadTest(): void {
  describe('SyncEngine upload pipeline', (): void => {

    // ================================================================
    // Unit test — no DB required
    // ================================================================

    // --- Test A: no appContext → NOTHING_TO_UPLOAD, no throw ---
    it('A) startUploadForTest without appContext → NOTHING_TO_UPLOAD', async (): Promise<void> => {
      let engine = makeSyncEngine(null);
      let result = await engine.startUploadForTest();
      expect(result === UploadResult.NOTHING_TO_UPLOAD).assertTrue();
    });

    // ================================================================
    // Integration tests — DB required
    // ================================================================

    // --- Test B: deleteLog upload → getDeleted returns keys first ---
    it('B) deleteLog populated → getDeleted returns keys (pre-upload state)', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.addToDeleteLog(1, 'item', ['DEL_B']);
        let deleted = await repo.getDeleted(1, 'item');
        expect(deleted.indexOf('DEL_B') >= 0).assertTrue();
        // cleanup
        await repo.removeFromDeleteLog(1, 'item', ['DEL_B']);
      });
    });

    // --- Test C: queued item → queue persists after createItem ---
    it('C) queued item → syncQueue contains key after createItem', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Queued Item C');
        let queue = await repo.getAllObjectsInQueue(1, 'item');
        expect(queue.indexOf(key) >= 0).assertTrue();
        // simulate successful upload removal
        await repo.removeFromSyncQueue(1, 'item', [key]);
        let after = await repo.getAllObjectsInQueue(1, 'item');
        expect(after.indexOf(key) < 0).assertTrue();
      });
    });

    // --- Test D: getObjectsForUpload → annotationID query ---
    it('D) getObjectsForUpload annotation → queries by annotationID, not parentItemID', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        // Create a parent PDF attachment + annotation via remote upsert
        await repo.upsertRemoteObject('item', {
          key: 'PDF_PARENT_D', version: 1,
          data: { itemType: 'attachment', linkMode: 'imported_file',
                  contentType: 'application/pdf', path: '/test.pdf' }
        });
        await repo.upsertRemoteObject('item', {
          key: 'ANNOT_D001', version: 1,
          data: {
            itemType: 'annotation', annotationType: 'highlight',
            annotationColor: '#00FF00', annotationText: 'green highlight',
            annotationComment: 'check this', annotationSortIndex: '00002',
            annotationPageLabel: '5',
            annotationPosition: '{"x":50,"y":60,"width":200,"height":30}',
            parentItem: 'PDF_PARENT_D',
          }
        });
        let objects = await repo.getObjectsForUpload(1, 'item', ['ANNOT_D001']);
        expect(objects.length === 1).assertTrue();
        let obj = objects[0];
        expect(obj['annotationType'] === 'highlight').assertTrue();
        expect(obj['annotationColor'] === '#00FF00').assertTrue();
        expect(obj['annotationComment'] === 'check this').assertTrue();
        expect(obj['parentItem'] === 'PDF_PARENT_D').assertTrue();
      });
    });

    // ================================================================
    // Additional: getObjectsForUpload serialization unchanged
    // ================================================================

    it('collection serialization → name + parentCollection', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createCollection('Upload Col', null);
        let objects = await repo.getObjectsForUpload(1, 'collection', [key]);
        expect(objects.length === 1).assertTrue();
        expect(objects[0]['name'] === 'Upload Col').assertTrue();
        expect(objects[0]['parentCollection'] === false).assertTrue();
      });
    });

    it('search serialization → conditions array', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createSavedSearch('Upload Search', [
          { condition: 'title', operator: 'contains', value: 'test', required: true },
        ]);
        let objects = await repo.getObjectsForUpload(1, 'search', [key]);
        expect(objects.length === 1).assertTrue();
        let conds = objects[0]['conditions'] as Record<string, Object>[];
        expect(conds.length === 1).assertTrue();
      });
    });

    it('item serialization → top-level fields + creators', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.upsertRemoteObject('item', {
          key: 'ITEM_SERIAL', version: 1,
          data: {
            itemType: 'book', title: 'Creator Test',
            creators: [{ creatorType: 'author', firstName: 'Dan', lastName: 'Brown' }],
            tags: [{ tag: 'bestseller', type: 0 }],
          }
        });
        let objects = await repo.getObjectsForUpload(1, 'item', ['ITEM_SERIAL']);
        expect(objects.length === 1).assertTrue();
        let obj = objects[0];
        expect(obj['title'] === 'Creator Test').assertTrue();
        let creators = obj['creators'] as Record<string, Object>[];
        expect(creators.length === 1).assertTrue();
        expect(creators[0]['lastName'] === 'Brown').assertTrue();
      });
    });

    it('remote upsert key → never appears in syncQueue', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.upsertRemoteObject('item', {
          key: 'REMOTE_ISOLATED', version: 1,
          data: { itemType: 'journalArticle', title: 'Remote Isolated' }
        });
        let queue = await repo.getAllObjectsInQueue(1, 'item');
        expect(queue.indexOf('REMOTE_ISOLATED') < 0).assertTrue();
      });
    });

  });
}
