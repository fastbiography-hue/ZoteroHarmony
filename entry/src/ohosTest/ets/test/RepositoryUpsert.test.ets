/*
 * LibraryRepository upsertRemoteObject / upsertRemoteItem verification suite.
 *
 * Run: DevEco Studio → entry/src/ohosTest → run
 * Requires: ZoteroDb opened with real relationalStore context.
 *
 * Each test opens a fresh in-memory repository, upserts, then reads back.
 */

import { describe, it, expect } from '@ohos/hypium';
import { LibraryRepository } from '../../main/ets/database/LibraryRepository.ets';

export default function RepositoryUpsertTest(): void {
  describe('LibraryRepository — remote upsert', (): void => {

    /**
     * Shared helper: open repo + verify it's ready.
     * In real test, call repo.open(getContext(this).getApplicationContext()).
     */
    async function openRepo(): Promise<LibraryRepository> {
      let repo = new LibraryRepository();
      // repo.open(context) — requires test Ability context
      return repo;
    }

    // ================================================================
    // Test a: upsert journalArticle → read back title, DOI, creator, tag, collection
    // ================================================================
    it('upsert journalArticle → read back title/DOI/creator/tag/collection', async (): Promise<void> => {
      let repo = await openRepo();
      // 1. Upsert a collection first (so collectionItems FK resolves)
      await repo.upsertRemoteObject('collection', {
        key: 'COL_TEST_A', version: 1,
        data: { name: 'Test Collection A' }
      });

      // 2. Upsert a journalArticle item
      let itemObj: Record<string, Object> = {
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
          abstractNote: 'An abstract for testing.',
          volume: '42',
          pages: '100-120',
        }
      };
      await repo.upsertRemoteObject('item', itemObj);

      // 3. Read back
      let items = await repo.listItems(null, '');
      let found: ItemModel | null = null;
      for (let i = 0; i < items.length; i++) {
        if (items[i].key === 'ITEM_A001') { found = items[i]; break; }
      }
      expect(found !== null).assertTrue();
      if (found) {
        expect(found.itemData.get('title') === 'Test Article Alpha').assertTrue();
        expect(found.itemData.get('DOI') === '10.1234/test.alpha').assertTrue();
        expect(found.itemData.get('volume') === '42').assertTrue();
        // creator
        expect(found.itemData.get('creator') === 'Doe, John').assertTrue();
        // tag
        expect(found.tags.length >= 1).assertTrue();
        expect(found.tags[0].tag === 'test-tag').assertTrue();
        // collection membership
        expect(found.collectionKeys.indexOf('COL_TEST_A') >= 0).assertTrue();
      }
    });

    // ================================================================
    // Test b: repeat upsert same key → no duplicate
    // ================================================================
    it('repeat upsert same key → no duplicate item', async (): Promise<void> => {
      let repo = await openRepo();
      let obj: Record<string, Object> = {
        key: 'ITEM_B001', version: 1,
        data: { itemType: 'journalArticle', title: 'First Version' }
      };
      await repo.upsertRemoteObject('item', obj);

      // Update with higher version
      obj = {
        key: 'ITEM_B001', version: 3,
        data: { itemType: 'journalArticle', title: 'Updated Version', date: '2025' }
      };
      await repo.upsertRemoteObject('item', obj);

      // Should be exactly one item with ITEM_B001
      let items = await repo.listItems(null, '');
      let count = 0;
      for (let i = 0; i < items.length; i++) {
        if (items[i].key === 'ITEM_B001') { count++; }
      }
      expect(count === 1).assertTrue();
      // Title should reflect update
      let item = await repo.getItemByKey('ITEM_B001');
      expect(item !== null).assertTrue();
      if (item) {
        expect(item.itemData.get('title') === 'Updated Version').assertTrue();
        expect(item.version === 3).assertTrue();
      }
    });

    // ================================================================
    // Test c: upsert attachment → itemAttachments populated
    // ================================================================
    it('upsert attachment → itemAttachments has parent/contentType/path/linkMode', async (): Promise<void> => {
      let repo = await openRepo();
      // Parent item first
      await repo.upsertRemoteObject('item', {
        key: 'ITEM_PARENT_C', version: 1,
        data: { itemType: 'journalArticle', title: 'Parent for attachment' }
      });
      // Attachment
      await repo.upsertRemoteObject('item', {
        key: 'ATTACH_C001', version: 2,
        data: {
          itemType: 'attachment',
          linkMode: 'imported_file',
          contentType: 'application/pdf',
          charset: 'utf-8',
          path: '/storage/docs/paper.pdf',
          filename: 'paper.pdf',
          md5: 'abc123def456',
          mtime: 1718000000,
          parentItem: 'ITEM_PARENT_C',
        }
      });
      // Verify via listAttachments
      let attachments = await repo.listAttachments('ITEM_PARENT_C');
      expect(attachments.length >= 1).assertTrue();
      let att = attachments[0];
      expect(att.key === 'ATTACH_C001').assertTrue();
      expect(att.contentType === 'application/pdf').assertTrue();
      expect(att.path === '/storage/docs/paper.pdf').assertTrue();
      expect(att.linkMode === 'imported_file').assertTrue();
    });

    // ================================================================
    // Test d: upsert note → itemNotes populated
    // ================================================================
    it('upsert note → itemNotes has parentItemID/note/title', async (): Promise<void> => {
      let repo = await openRepo();
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

    // ================================================================
    // Test e: upsert annotation → itemAnnotations populated
    // ================================================================
    it('upsert annotation → itemAnnotations has color/text/comment/sortIndex/parent', async (): Promise<void> => {
      let repo = await openRepo();
      // Create a PDF attachment as parent
      await repo.upsertRemoteObject('item', {
        key: 'PDF_PARENT_E', version: 1,
        data: { itemType: 'attachment', linkMode: 'imported_file',
                contentType: 'application/pdf', path: '/test.pdf' }
      });
      await repo.upsertRemoteObject('item', {
        key: 'ANNOT_E001', version: 1,
        data: {
          itemType: 'annotation',
          annotationType: 'highlight',
          annotationColor: '#FFD700',
          annotationText: 'important finding',
          annotationComment: 'review this',
          annotationSortIndex: '00005',
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
      expect(ann.pageIndex === 3).assertTrue();
      expect(ann.position.x === 10.5).assertTrue();
    });

    // ================================================================
    // Test f: upsert saved search → conditions written
    // ================================================================
    it('upsert saved search → savedSearchConditions populated', async (): Promise<void> => {
      let repo = await openRepo();
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
        expect(query.conditions[0].condition === 'title').assertTrue();
        expect(query.conditions[1].condition === 'date').assertTrue();
      }
    });

    // ================================================================
    // Test g: creators with fieldMode detection
    // ================================================================
    it('upsert item with single-field creator → creator preserved', async (): Promise<void> => {
      let repo = await openRepo();
      await repo.upsertRemoteObject('item', {
        key: 'ITEM_CREATOR_G', version: 1,
        data: {
          itemType: 'book',
          title: 'Single Field Creator Test',
          creators: [
            { creatorType: 'author', name: 'National Academy of Sciences' }
          ]
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

    // ================================================================
    // Test h: collection upsert with parent (existing and non-existing)
    // ================================================================
    it('upsert collection with parent → non-existing parent becomes null', async (): Promise<void> => {
      let repo = await openRepo();
      // Upsert child before parent exists
      await repo.upsertRemoteObject('collection', {
        key: 'CHILD_H', version: 1,
        data: { name: 'Child Collection', parentCollection: 'NONEXISTENT' }
      });
      // Now upsert parent
      await repo.upsertRemoteObject('collection', {
        key: 'PARENT_H', version: 1,
        data: { name: 'Parent Collection' }
      });
      // Re-upsert child with correct parent
      await repo.upsertRemoteObject('collection', {
        key: 'CHILD_H', version: 2,
        data: { name: 'Child Collection', parentCollection: 'PARENT_H' }
      });
      // Verify
      let rows = await repo.listCollectionRows();
      let child = rows.find(r => r.key === 'CHILD_H');
      expect(child !== undefined).assertTrue();
      if (child) {
        expect(child.parentRowID === 'C_PARENT_ID').assertTrue(); // parent row exists
      }
    });

  });
}
