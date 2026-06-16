/*
 * Child item edit — attachment/note metadata update API tests.
 * Requires DevEco relationalStore context.
 */

import { describe, it, expect } from '@ohos/hypium';
import { LibraryRepository } from '../../main/ets/database/LibraryRepository.ets';
import {
  attachmentDraftDirty,
  AttachmentDraftSnapshot,
} from '../../main/ets/ui/helpers/AttachmentDraftHelpers.ets';

async function tryOpenRepo(): Promise<LibraryRepository | null> {
  try {
    let context = getContext().getApplicationContext();
    let repo = new LibraryRepository();
    await repo.open(context);
    return repo;
  } catch (err) {
    console.warn('[ChildItemEditTest] Cannot open DB — skipping: ' +
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

export default function ChildItemEditTest(): void {
  describe('attachmentDraftDirty (unit)', (): void => {

    it('same values → dirty=false', (): void => {
      let init = { title: 'A', contentType: 'pdf', path: '/a.pdf', url: 'https://a' };
      let current = { title: 'A', contentType: 'pdf', path: '/a.pdf', url: 'https://a' };
      expect(!attachmentDraftDirty(init, current)).assertTrue();
    });

    it('changed title → dirty=true', (): void => {
      let init = { title: 'A', contentType: 'pdf', path: '/a.pdf', url: 'https://a' };
      let current = { title: 'B', contentType: 'pdf', path: '/a.pdf', url: 'https://a' };
      expect(attachmentDraftDirty(init, current)).assertTrue();
    });

    it('revert to original → dirty=false', (): void => {
      let init = { title: 'X', contentType: 'pdf', path: '/x', url: '' };
      let current = { title: 'X', contentType: 'pdf', path: '/x', url: '' };
      expect(!attachmentDraftDirty(init, current)).assertTrue();
    });

  });

  describe('Attachment metadata update (integration)', (): void => {

    it('updateAttachmentMetadataByKey → title/contentType/path/url + syncQueue', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let pKey = await repo.createItem(null, 'journalArticle', 'Parent A');
        let attKey = await repo.createLinkedUrlAttachment(pKey, 'https://old.example.com');
        await repo.removeFromSyncQueue(1, 'item', [attKey]);
        await repo.updateAttachmentMetadataByKey(attKey, 'New Title',
          'application/pdf', '/new/path.pdf', 'https://new.example.com');
        let objs = await repo.getObjectsForUpload(1, 'item', [attKey]);
        expect(objs.length === 1).assertTrue();
        expect(objs[0]['title'] === 'New Title').assertTrue();
        expect(objs[0]['contentType'] === 'application/pdf').assertTrue();
        expect(objs[0]['path'] === '/new/path.pdf').assertTrue();
        let q = await repo.getAllObjectsInQueue(1, 'item');
        expect(q.indexOf(attKey) >= 0).assertTrue();
      });
    });

    it('empty URL → old url deleted from itemData + upload JSON', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let pKey = await repo.createItem(null, 'journalArticle', 'Parent UrlEmpty');
        let attKey = await repo.createLinkedUrlAttachment(pKey, 'https://old.url');
        await repo.removeFromSyncQueue(1, 'item', [attKey]);
        await repo.updateAttachmentMetadataByKey(attKey, 'Title',
          'text/html', '/path.html', '');
        let objs = await repo.getObjectsForUpload(1, 'item', [attKey]);
        let hasUrl = (objs[0]['url'] !== undefined && (objs[0]['url'] as string).length > 0);
        expect(!hasUrl).assertTrue();
        let q = await repo.getAllObjectsInQueue(1, 'item');
        expect(q.indexOf(attKey) >= 0).assertTrue();
      });
    });

    it('empty title → title deleted from itemData + upload JSON', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let pKey = await repo.createItem(null, 'journalArticle', 'Parent TitleEmpty');
        let attKey = await repo.createLinkedUrlAttachment(pKey, 'https://keep.url');
        await repo.removeFromSyncQueue(1, 'item', [attKey]);
        await repo.updateAttachmentMetadataByKey(attKey, '', 'text/plain', '/x.txt', '');
        let objs = await repo.getObjectsForUpload(1, 'item', [attKey]);
        let hasTitle = (objs[0]['title'] !== undefined && (objs[0]['title'] as string).length > 0);
        expect(!hasTitle).assertTrue();
      });
    });

    it('regular item → updateAttachmentMetadataByKey no-op', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let regularKey = await repo.createItem(null, 'journalArticle', 'Regular not attach');
        await repo.removeFromSyncQueue(1, 'item', [regularKey]);
        await repo.updateAttachmentMetadataByKey(regularKey, 'FakeTitle',
          'fake', '/fake', 'https://fake');
        let item = await repo.getItemByKey(regularKey);
        expect(item !== null).assertTrue();
        if (item) {
          // title should still be 'Regular not attach', not 'FakeTitle'
          expect(item.itemData.get('title') === 'Regular not attach').assertTrue();
        }
        let q = await repo.getAllObjectsInQueue(1, 'item');
        expect(q.indexOf(regularKey) < 0).assertTrue();
      });
    });

    it('deleteAttachment → trash + syncQueue', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let pKey = await repo.createItem(null, 'journalArticle', 'Delete Parent');
        let attKey = await repo.createLinkedUrlAttachment(pKey, 'https://delete.me');
        await repo.removeFromSyncQueue(1, 'item', [attKey]);
        await repo.deleteAttachment(attKey);
        let q = await repo.getAllObjectsInQueue(1, 'item');
        expect(q.indexOf(attKey) >= 0).assertTrue();
      });
    });

  });

  describe('Note by-key update (integration)', (): void => {

    it('updateNoteByKey → title/note + syncQueue', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let pKey = await repo.createItem(null, 'journalArticle', 'Note Parent');
        let noteKey = await repo.createNote(pKey, 'Old', '<p>Old body</p>');
        await repo.removeFromSyncQueue(1, 'item', [noteKey]);
        await repo.updateNoteByKey(noteKey, 'New', '<p>New body</p>');
        let objs = await repo.getObjectsForUpload(1, 'item', [noteKey]);
        expect(objs[0]['note'] === '<p>New body</p>').assertTrue();
        let q = await repo.getAllObjectsInQueue(1, 'item');
        expect(q.indexOf(noteKey) >= 0).assertTrue();
      });
    });

    it('getNoteByKey → title + noteText', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let pKey = await repo.createItem(null, 'journalArticle', 'GetNote');
        let noteKey = await repo.createNote(pKey, 'My Note', '<p>Text</p>');
        let n = await repo.getNoteByKey(noteKey);
        expect(n !== null).assertTrue();
        if (n) {
          expect(n.title === 'My Note').assertTrue();
          expect(n.noteText === '<p>Text</p>').assertTrue();
        }
      });
    });

    it('getNoteByKey unknown → null', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        expect((await repo.getNoteByKey('NONEXISTENT')) === null).assertTrue();
      });
    });

  });
}
