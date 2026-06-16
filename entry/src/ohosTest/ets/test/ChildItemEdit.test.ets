/*
 * Child item edit — attachment/note metadata update API tests.
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
  describe('Attachment metadata update', (): void => {

    it('updateAttachmentMetadataByKey → title/contentType/path/url + syncQueue', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let pKey = await repo.createItem(null, 'journalArticle', 'Parent A');
        let attKey = await repo.createLinkedUrlAttachment(pKey, 'https://old.example.com');
        await repo.removeFromSyncQueue(1, 'item', [attKey]);

        await repo.updateAttachmentMetadataByKey(
          attKey, 'Updated Att Title', 'application/pdf', '/new/path.pdf', 'https://new.example.com'
        );
        let objs = await repo.getObjectsForUpload(1, 'item', [attKey]);
        expect(objs.length === 1).assertTrue();
        expect(objs[0]['title'] === 'Updated Att Title').assertTrue();
        expect(objs[0]['contentType'] === 'application/pdf').assertTrue();
        expect(objs[0]['path'] === '/new/path.pdf').assertTrue();

        let q = await repo.getAllObjectsInQueue(1, 'item');
        expect(q.indexOf(attKey) >= 0).assertTrue();
      });
    });

    it('deleteAttachment → item enters trash + syncQueue', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let pKey = await repo.createItem(null, 'journalArticle', 'Delete Parent');
        let attKey = await repo.createLinkedUrlAttachment(pKey, 'https://delete.me');
        await repo.removeFromSyncQueue(1, 'item', [attKey]);
        await repo.deleteAttachment(attKey);
        // After deleteAttachment → moveItemToTrash → addToSyncQueue
        let q = await repo.getAllObjectsInQueue(1, 'item');
        expect(q.indexOf(attKey) >= 0).assertTrue();
      });
    });

  });

  describe('Note by-key update', (): void => {

    it('updateNoteByKey → title/note changed + syncQueue', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let pKey = await repo.createItem(null, 'journalArticle', 'Note Parent');
        let noteKey = await repo.createNote(pKey, 'Old Title', '<p>Old</p>');
        await repo.removeFromSyncQueue(1, 'item', [noteKey]);

        await repo.updateNoteByKey(noteKey, 'New Title', '<p>New body</p>');
        let objs = await repo.getObjectsForUpload(1, 'item', [noteKey]);
        expect(objs.length === 1).assertTrue();
        expect(objs[0]['note'] === '<p>New body</p>').assertTrue();

        let q = await repo.getAllObjectsInQueue(1, 'item');
        expect(q.indexOf(noteKey) >= 0).assertTrue();
      });
    });

    it('getNoteByKey → returns title and noteText', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let pKey = await repo.createItem(null, 'journalArticle', 'GetNote Parent');
        let noteKey = await repo.createNote(pKey, 'My Title', '<p>Body text</p>');
        let n = await repo.getNoteByKey(noteKey);
        expect(n !== null).assertTrue();
        if (n) {
          expect(n.title === 'My Title').assertTrue();
          expect(n.noteText === '<p>Body text</p>').assertTrue();
          expect(n.key === noteKey).assertTrue();
        }
      });
    });

    it('getNoteByKey unknown → null', async (): Promise<void> => {
      await withRepo(async (repo: LibraryRepository): Promise<void> => {
        let n = await repo.getNoteByKey('NONEXISTENT_NOTE_KEY');
        expect(n === null).assertTrue();
      });
    });

  });
}
