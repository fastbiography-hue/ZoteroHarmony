/*
 * Core Workflow Parity — createItem / createCollection / identifier tests.
 * Requires DevEco relationalStore context.
 */

import { describe, it, expect } from '@ohos/hypium';
import { LibraryRepository } from '../../main/ets/database/LibraryRepository.ets';
import { IdentifierLookup } from '../../main/ets/import/IdentifierLookup.ets';

async function tryOpenRepo(): Promise<LibraryRepository | null> {
  try {
    let context = getContext().getApplicationContext();
    let repo = new LibraryRepository();
    await repo.open(context);
    return repo;
  } catch (err) {
    console.warn('[CoreWorkflowParityTest] Cannot open DB — skipping: ' +
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

export default function CoreWorkflowParityTest(): void {
  describe('IdentifierLookup (unit)', (): void => {

    it('classify → DOI', (): void => {
      expect(IdentifierLookup.classify('10.1234/foo.bar') === 'doi').assertTrue();
    });

    it('classify → ISBN-13', (): void => {
      expect(IdentifierLookup.classify('978-3-16-148410-0') === 'isbn').assertTrue();
    });

    it('classify → arXiv', (): void => {
      expect(IdentifierLookup.classify('1901.01234') === 'arxiv').assertTrue();
    });

    it('classify → PMID', (): void => {
      expect(IdentifierLookup.classify('12345678') === 'pmid').assertTrue();
    });

    it('classify → unknown', (): void => {
      expect(IdentifierLookup.classify('just some text') === 'unknown').assertTrue();
    });

  });

  describe('createItem / createCollection (integration)', (): void => {

    it('createItem → itemType and title persisted', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createItem(null, 'book', 'My Test Book');
        let item = await repo.getItemByKey(key);
        expect(item !== null).assertTrue();
        if (item) {
          expect(item.itemData.get('title') === 'My Test Book').assertTrue();
          expect(item.itemData.get('itemType') === 'book').assertTrue();
        }
        let q = await repo.getAllObjectsInQueue(1, 'item');
        expect(q.indexOf(key) >= 0).assertTrue();
      });
    });

    it('createItem in collection → item listable by collection', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let colKey = await repo.createCollection('Test Col', null);
        let itemKey = await repo.createItem(colKey, 'journalArticle', 'Article in Col');
        let items = await repo.listItems(colKey, '');
        let found = false;
        for (let i = 0; i < items.length; i++) {
          if (items[i].key === itemKey) { found = true; break; }
        }
        expect(found).assertTrue();
      });
    });

    it('createCollection → returns key, appears in list', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let key = await repo.createCollection('Named Col', null);
        expect(key.length > 0).assertTrue();
        let rows = await repo.listCollectionRows();
        let found = false;
        for (let i = 0; i < rows.length; i++) {
          if (rows[i].key === key) { found = true; break; }
        }
        expect(found).assertTrue();
        let q = await repo.getAllObjectsInQueue(1, 'collection');
        expect(q.indexOf(key) >= 0).assertTrue();
      });
    });

  });
}
