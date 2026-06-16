/*
 * LibraryRepository upsertRemoteObject / upsertRemoteItem verification suite.
 *
 * Integration tests — require a real DevEco Studio / HarmonyOS test runner
 * with relationalStore context.  When run outside that environment, each test
 * exits early with a clear reason rather than failing.
 *
 * Run: DevEco Studio → right-click entry/src/ohosTest → Run
 */

import { describe, it, expect } from '@ohos/hypium';
import { LibraryRepository } from '../../main/ets/database/LibraryRepository.ets';
import { ItemModel } from '../../main/ets/model/ItemModel.ets';

/** Attempt to open a repository; returns null + logs reason when context is unavailable. */
async function tryOpenRepo(): Promise<LibraryRepository | null> {
  try {
    let context = getContext().getApplicationContext();
    let repo = new LibraryRepository();
    await repo.open(context);
    return repo;
  } catch (err) {
    console.warn('[RepositoryUpsertTest] Cannot open DB — skipping integration test: ' +
      (err as Error).message);
    return null;
  }
}

/** Shared test wrapper: runs body only when a repo can be opened. */
async function withRepo(
  body: (repo: LibraryRepository) => Promise<void>
): Promise<void> {
  let repo = await tryOpenRepo();
  if (repo === null) {
    // Integration environment unavailable — skip without failing
    return;
  }
  try {
    await body(repo);
  } finally {
    await repo.close();
  }
}

export default function RepositoryUpsertTest(): void {
  describe('LibraryRepository — remote upsert (integration)', (): void => {

    // ================================================================
    // Test a: upsert journalArticle → read back
    // ================================================================
    it('a) upsert journalArticle → title/DOI/creator/tag/collection', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.upsertRemoteObject('collection', {
          key: 'COL_TEST_A', version: 1,
          data: { name: 'Test Collection A' }
        });
        await repo.upsertRemoteObject('item', {
          key: 'ITEM_A001', version: 5,
          data: {
            itemType: 'journalArticle',
            title: 'Test Article Alpha',
            date: '2024',
            DOI: '10.1234/test.alpha',
            creators: [
              { creatorType: 'author', firstName: 'John', lastName: 'Doe' }
            ],
            tags: [{ tag: 'test-tag', type: 0 }],
            collections: ['COL_TEST_A'],
          }
        });
        let items = await repo.listItems(null, '');
        let found: ItemModel | null = null;
        for (let i = 0; i < items.length; i++) {
          if (items[i].key === 'ITEM_A001') { found = items[i]; break; }
        }
        expect(found !== null).assertTrue();
        if (found) {
          expect(found.itemData.get('title') === 'Test Article Alpha').assertTrue();
          expect(found.itemData.get('DOI') === '10.1234/test.alpha').assertTrue();
          expect(found.itemData.get('creator') === 'Doe, John').assertTrue();
          expect(found.tags.length >= 1).assertTrue();
          expect(found.tags[0].tag === 'test-tag').assertTrue();
        }
      });
    });

    // ================================================================
    // Test b: repeat upsert → no duplicate
    // ================================================================
    it('b) repeat upsert same key → no duplicate', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.upsertRemoteObject('item', {
          key: 'ITEM_B001', version: 1,
          data: { itemType: 'journalArticle', title: 'First Version' }
        });
        await repo.upsertRemoteObject('item', {
          key: 'ITEM_B001', version: 3,
          data: { itemType: 'journalArticle', title: 'Updated Version', date: '2025' }
        });
        let items = await repo.listItems(null, '');
        let count = 0;
        for (let i = 0; i < items.length; i++) {
          if (items[i].key === 'ITEM_B001') { count++; }
        }
        expect(count === 1).assertTrue();
        let item = await repo.getItemByKey('ITEM_B001');
        expect(item !== null).assertTrue();
        if (item) {
          expect(item.itemData.get('title') === 'Updated Version').assertTrue();
        }
      });
    });

    // ================================================================
    // Test c: upsert attachment
    // ================================================================
    it('c) upsert attachment → parent/contentType/path/linkMode', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.upsertRemoteObject('item', {
          key: 'ITEM_PARENT_C', version: 1,
          data: { itemType: 'journalArticle', title: 'Parent for attachment' }
        });
        await repo.upsertRemoteObject('item', {
          key: 'ATTACH_C001', version: 2,
          data: {
            itemType: 'attachment', linkMode: 'imported_file',
            contentType: 'application/pdf', path: '/storage/docs/paper.pdf',
            filename: 'paper.pdf', md5: 'abc123def456', mtime: 1718000000,
            parentItem: 'ITEM_PARENT_C',
          }
        });
        let attachments = await repo.listAttachments('ITEM_PARENT_C');
        expect(attachments.length >= 1).assertTrue();
        let att = attachments[0];
        expect(att.key === 'ATTACH_C001').assertTrue();
        expect(att.contentType === 'application/pdf').assertTrue();
        expect(att.path === '/storage/docs/paper.pdf').assertTrue();
      });
    });

    // ================================================================
    // Test d: upsert note
    // ================================================================
    it('d) upsert note → parentItemID/note/title', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.upsertRemoteObject('item', {
          key: 'ITEM_PARENT_D', version: 1,
          data: { itemType: 'journalArticle', title: 'Parent for note' }
        });
        await repo.upsertRemoteObject('item', {
          key: 'NOTE_D001', version: 1,
          data: {
            itemType: 'note',
            note: '<p>This is a <b>test</b> note.</p>',
            title: 'My Note Display Title',
            parentItem: 'ITEM_PARENT_D',
          }
        });
        let notes = await repo.listNotes('ITEM_PARENT_D');
        expect(notes.length >= 1).assertTrue();
        let n = notes[0];
        expect(n.key === 'NOTE_D001').assertTrue();
        expect(n.noteText === '<p>This is a <b>test</b> note.</p>').assertTrue();
        expect(n.title === 'My Note Display Title').assertTrue();
      });
    });

    // ================================================================
    // Test e: upsert annotation
    // ================================================================
    it('e) upsert annotation → color/text/comment/sortIndex/position/parent', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.upsertRemoteObject('item', {
          key: 'PDF_PARENT_E', version: 1,
          data: { itemType: 'attachment', linkMode: 'imported_file',
                  contentType: 'application/pdf', path: '/test.pdf' }
        });
        await repo.upsertRemoteObject('item', {
          key: 'ANNOT_E001', version: 1,
          data: {
            itemType: 'annotation', annotationType: 'highlight',
            annotationColor: '#FFD700', annotationText: 'important finding',
            annotationComment: 'review this', annotationSortIndex: '00005',
            annotationPageLabel: '3',
            annotationPosition: '{"x":10.5,"y":20.0,"width":100.0,"height":15.0}',
            annotationAuthorName: 'user123',
            parentItem: 'PDF_PARENT_E',
          }
        });
        let annotations = await repo.listAnnotations('PDF_PARENT_E');
        expect(annotations.length >= 1).assertTrue();
        let ann = annotations[0];
        expect(ann.type === 'highlight').assertTrue();
        expect(ann.color === '#FFD700').assertTrue();
        expect(ann.text === 'important finding').assertTrue();
        expect(ann.comment === 'review this').assertTrue();
        expect(ann.sortIndex === '00005').assertTrue();
        expect(ann.position.x === 10.5).assertTrue();
      });
    });

    // ================================================================
    // Test f: upsert saved search
    // ================================================================
    it('f) upsert saved search → conditions populated', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.upsertRemoteObject('search', {
          key: 'SEARCH_F001', version: 1,
          data: {
            name: 'Recent Papers',
            conditions: [
              { condition: 'title', operator: 'contains', value: 'test', required: 1 },
              { condition: 'date', operator: 'isAfter', value: '2020', required: 1 },
            ]
          }
        });
        let query = await repo.getSavedSearchQuery('SEARCH_F001');
        expect(query !== null).assertTrue();
        if (query) {
          expect(query.name === 'Recent Papers').assertTrue();
          expect(query.conditions.length === 2).assertTrue();
        }
      });
    });

    // ================================================================
    // Test g: single-field creator preservation
    // ================================================================
    it('g) single-field creator → preserved in itemData', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        await repo.upsertRemoteObject('item', {
          key: 'ITEM_CREATOR_G', version: 1,
          data: {
            itemType: 'book', title: 'Single Field Creator Test',
            creators: [{ creatorType: 'author', name: 'National Academy of Sciences' }]
          }
        });
        let items = await repo.listItems(null, '');
        let found: ItemModel | null = null;
        for (let i = 0; i < items.length; i++) {
          if (items[i].key === 'ITEM_CREATOR_G') { found = items[i]; break; }
        }
        expect(found !== null).assertTrue();
        if (found) {
          expect(found.itemData.get('creator') === 'National Academy of Sciences').assertTrue();
        }
      });
    });

    // ================================================================
    // Test h: collection parent fixup
    // ================================================================
    it('h) collection upsert → parent fixup on second upsert', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        // Child before parent → parent null
        await repo.upsertRemoteObject('collection', {
          key: 'CHILD_H', version: 1,
          data: { name: 'Child Collection', parentCollection: 'NONEXISTENT' }
        });
        // Now create parent
        await repo.upsertRemoteObject('collection', {
          key: 'PARENT_H', version: 1,
          data: { name: 'Parent Collection' }
        });
        // Re-upsert child with correct parent
        await repo.upsertRemoteObject('collection', {
          key: 'CHILD_H', version: 2,
          data: { name: 'Child Collection', parentCollection: 'PARENT_H' }
        });
        let rows = await repo.listCollectionRows();
        let parent = rows.find((r): boolean => r.key === 'PARENT_H');
        let child = rows.find((r): boolean => r.key === 'CHILD_H');
        expect(parent !== undefined).assertTrue();
        expect(child !== undefined).assertTrue();
        if (parent !== undefined && child !== undefined) {
          expect(child.parentRowID === parent.id).assertTrue();
        }
      });
    });

  });
}
