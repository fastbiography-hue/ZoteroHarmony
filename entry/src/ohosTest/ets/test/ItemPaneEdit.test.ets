/*
 * ItemPane edit closure — Repository update API + helper tests.
 * Unit tests (without DB) run always.
 * Integration tests require DevEco context and skip gracefully.
 */

import { describe, it, expect } from '@ohos/hypium';
import { LibraryRepository } from '../../main/ets/database/LibraryRepository.ets';
import { ZoteroCreator, ZoteroTag } from '../../main/ets/model/ItemTypes.ets';
import {
  creatorsToJson, creatorsJsonEqual,
  tagsToJson, tagsJsonEqual,
} from '../../main/ets/ui/helpers/ItemDetailsHelpers.ets';

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
  describe('creatorsToJson / tagsToJson (unit)', (): void => {

    it('creatorsToJson includes name for fieldMode=1', (): void => {
      let c: ZoteroCreator[] = [
        { creatorType: 'author', firstName: '', lastName: '', fieldMode: 1, name: 'Consortium X' }
      ];
      let json = creatorsToJson(c);
      // json string must contain the name
      expect(json.includes('Consortium X')).assertTrue();
      expect(creatorsJsonEqual(json, c)).assertTrue();
    });

    it('creatorsJsonEqual → false when name differs', (): void => {
      let a: ZoteroCreator[] = [
        { creatorType: 'author', firstName: '', lastName: '', fieldMode: 1, name: 'Org A' }
      ];
      let json = creatorsToJson(a);
      let b: ZoteroCreator[] = [
        { creatorType: 'author', firstName: '', lastName: '', fieldMode: 1, name: 'Org B' }
      ];
      expect(!creatorsJsonEqual(json, b)).assertTrue();
    });

    it('creatorsJsonEqual → same creators are equal', (): void => {
      let a: ZoteroCreator[] = [
        { creatorType: 'author', firstName: 'Ada', lastName: 'Lovelace', fieldMode: 0 }
      ];
      expect(creatorsJsonEqual(creatorsToJson(a), a)).assertTrue();
    });

    it('tagsJsonEqual → same tags true', (): void => {
      let tags: ZoteroTag[] = [{ tag: 'important', type: 0 }, { tag: 'draft', type: 1 }];
      expect(tagsJsonEqual(tagsToJson(tags), tags)).assertTrue();
    });

    it('tagsJsonEqual → different tags false', (): void => {
      let tagsA: ZoteroTag[] = [{ tag: 'a', type: 0 }];
      let tagsB: ZoteroTag[] = [{ tag: 'b', type: 0 }];
      expect(!tagsJsonEqual(tagsToJson(tagsA), tagsB)).assertTrue();
    });

    it('tagsJsonEqual → different count false', (): void => {
      let tags: ZoteroTag[] = [{ tag: 'x', type: 0 }];
      expect(!tagsJsonEqual(tagsToJson(tags), [])).assertTrue();
    });

  });

  describe('Repository update APIs (integration)', (): void => {

    it('updateItemField → value + syncQueue', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Field Test');
        await repo.removeFromSyncQueue(1, 'item', [key]);
        await repo.updateItemField(key, 'DOI', '10.1234/test');
        let item = await repo.getItemByKey(key);
        expect(item !== null).assertTrue();
        if (item) { expect(item.itemData.get('DOI') === '10.1234/test').assertTrue(); }
        let q = await repo.getAllObjectsInQueue(1, 'item');
        expect(q.indexOf(key) >= 0).assertTrue();
      });
    });

    it('updateItemField empty → deleted', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Empty Test');
        await repo.updateItemField(key, 'DOI', 'to.delete');
        await repo.removeFromSyncQueue(1, 'item', [key]);
        await repo.updateItemField(key, 'DOI', '');
        let item = await repo.getItemByKey(key);
        let hasField = item !== null && (item!.itemData.get('DOI') ?? '').length > 0;
        expect(!hasField).assertTrue();
      });
    });

    it('updateItemType unsupported → no change', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Type Safe');
        await repo.removeFromSyncQueue(1, 'item', [key]);
        await repo.updateItemTypeByKey(key, 'notARealType');
        let item = await repo.getItemByKey(key);
        expect(item !== null).assertTrue();
        if (item) { expect(item.itemData.get('itemType') === 'journalArticle').assertTrue(); }
        let q = await repo.getAllObjectsInQueue(1, 'item');
        expect(q.indexOf(key) < 0).assertTrue();
      });
    });

    it('updateItemCreatorsByKey → two-field creator in upload', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Creator Test');
        await repo.removeFromSyncQueue(1, 'item', [key]);
        await repo.updateItemCreatorsByKey(key, [
          { creatorType: 'author', firstName: 'Ada', lastName: 'Lovelace', fieldMode: 0 }
        ]);
        let objs = await repo.getObjectsForUpload(1, 'item', [key]);
        let cs = objs[0]['creators'] as Record<string, Object>[];
        expect(cs.length === 1).assertTrue();
        expect(cs[0]['lastName'] === 'Lovelace').assertTrue();
        let q = await repo.getAllObjectsInQueue(1, 'item');
        expect(q.indexOf(key) >= 0).assertTrue();
      });
    });

    it('updateItemCreatorsByKey → single-field creator (name) in upload', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'SingleField Test');
        await repo.updateItemCreatorsByKey(key, [
          { creatorType: 'author', firstName: '', lastName: '', fieldMode: 1, name: 'Consortium X' }
        ]);
        let objs = await repo.getObjectsForUpload(1, 'item', [key]);
        let cs = objs[0]['creators'] as Record<string, Object>[];
        expect(cs.length === 1).assertTrue();
        // Single-field: stored as name or lastName per serialization
        let hasName = cs[0]['lastName'] === 'Consortium X' || cs[0]['name'] === 'Consortium X';
        expect(hasName).assertTrue();
      });
    });

    it('updateItemCreatorsByKey replace → old gone', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Replace Test');
        await repo.updateItemCreatorsByKey(key, [
          { creatorType: 'author', firstName: 'Old', lastName: 'Guy', fieldMode: 0 }
        ]);
        await repo.updateItemCreatorsByKey(key, [
          { creatorType: 'editor', firstName: 'New', lastName: 'Editor', fieldMode: 0 }
        ]);
        let objs = await repo.getObjectsForUpload(1, 'item', [key]);
        let cs = objs[0]['creators'] as Record<string, Object>[];
        expect(cs.length === 1).assertTrue();
        expect(cs[0]['lastName'] === 'Editor').assertTrue();
      });
    });

    it('updateItemCreatorsByKey empty → no creators', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'journalArticle', 'Empty Creator');
        await repo.updateItemCreatorsByKey(key, [
          { creatorType: 'author', firstName: 'T', lastName: 'P', fieldMode: 0 }
        ]);
        await repo.updateItemCreatorsByKey(key, []);
        let objs = await repo.getObjectsForUpload(1, 'item', [key]);
        expect(objs[0]['creators'] === undefined).assertTrue();
      });
    });

    it('remote → no queue; local edit → queue', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.upsertRemoteObject('item', {
          key: 'REMOTE_E7', version: 1,
          data: { itemType: 'journalArticle', title: 'Remote Local' }
        });
        let qb = await repo.getAllObjectsInQueue(1, 'item');
        expect(qb.indexOf('REMOTE_E7') < 0).assertTrue();
        await repo.updateItemField('REMOTE_E7', 'DOI', '10.9999/local');
        let qa = await repo.getAllObjectsInQueue(1, 'item');
        expect(qa.indexOf('REMOTE_E7') >= 0).assertTrue();
      });
    });

  });
}
