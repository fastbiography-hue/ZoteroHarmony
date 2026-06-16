/*
 * ItemModel.fromJSON / toJSON / semantic checks — verification suite.
 * Run: DevEco Studio → entry/src/ohosTest → run
 */

import { describe, it, expect } from '@ohos/hypium';
import { ItemModel } from '../../main/ets/model/ItemModel.ets';
import { AttachmentLinkMode, AnnotationTypeEnum } from '../../main/ets/model/ItemTypes.ets';

export default function ItemModelTest(): void {
  describe('ItemModel — fromJSON semantics', (): void => {

    // ================================================================
    // Test a: journalArticle → isRegularItem() === true
    // ================================================================
    it('journalArticle fromJSON → isRegularItem() === true', (): void => {
      let json: Record<string, Object> = {
        data: {
          key: 'ITEM001', version: 1,
          itemType: 'journalArticle',
          title: 'Attention Is All You Need',
          date: '2017',
          DOI: '10.1234/neurips.2017',
          creators: [
            { creatorType: 'author', firstName: 'Ashish', lastName: 'Vaswani' }
          ],
          tags: [{ tag: 'transformer', type: 0 }],
          collections: ['COL_KEY_1'],
          relations: { 'dc:relation': ['ITEM002'] },
          abstractNote: 'The dominant sequence transduction models…',
          volume: '30',
          pages: '5998-6008',
          publicationTitle: 'Advances in Neural Information Processing Systems',
          publisher: 'NeurIPS',
        }
      };
      let item = new ItemModel();
      item.fromJSON(json);
      // a: isRegularItem should be true (itemTypeName='journalArticle' ≠ note/attachment/annotation)
      expect(item.isRegularItem()).assertTrue();
    });

    // ================================================================
    // Test b: journalArticle toJSON('full').itemType === 'journalArticle'
    // ================================================================
    it('journalArticle toJSON → itemType preserved', (): void => {
      let json: Record<string, Object> = {
        data: { key: 'ITEM002', version: 2, itemType: 'journalArticle', title: 'Test' }
      };
      let item = new ItemModel();
      item.fromJSON(json);
      let out = item.toJSON('full');
      expect(out.itemType === 'journalArticle').assertTrue();
    });

    // ================================================================
    // Test c: journalArticle toJSON('full').creators not lost
    // ================================================================
    it('journalArticle toJSON → creators preserved', (): void => {
      let json: Record<string, Object> = {
        data: {
          key: 'ITEM003', version: 3,
          itemType: 'journalArticle',
          title: 'A Survey of LLMs',
          creators: [
            { creatorType: 'author', firstName: 'Wayne', lastName: 'Zhao' }
          ]
        }
      };
      let item = new ItemModel();
      item.fromJSON(json);
      let out = item.toJSON('full');
      expect(out.creators !== undefined).assertTrue();
      expect(out.creators!.length === 1).assertTrue();
      expect(out.creators![0].lastName === 'Zhao').assertTrue();
    });

    // ================================================================
    // Test d: attachment fromJSON → isAttachment()===true, isRegularItem()===false
    // ================================================================
    it('attachment fromJSON → isAttachment()===true, isRegularItem()===false', (): void => {
      let json: Record<string, Object> = {
        data: {
          key: 'ATTACH01', version: 1,
          itemType: 'attachment',
          linkMode: 'imported_file',
          contentType: 'application/pdf',
          filename: 'paper.pdf',
          path: '/storage/papers/paper.pdf',
          charset: 'utf-8',
          md5: 'd41d8cd98f00b204e9800998ecf8427e',
          parentItem: 'ITEM001',
        }
      };
      let item = new ItemModel();
      item.fromJSON(json);
      expect(item.isAttachment()).assertTrue();
      expect(item.isRegularItem()).assertFalse();
      expect(item.attachmentLinkMode === AttachmentLinkMode.IMPORTED_FILE).assertTrue();
      expect(item.attachmentContentType === 'application/pdf').assertTrue();
      expect(item.attachmentPath === '/storage/papers/paper.pdf').assertTrue();
      expect(item.attachmentCharset === 'utf-8').assertTrue();
      expect(item.attachmentSyncedHash === 'd41d8cd98f00b204e9800998ecf8427e').assertTrue();
      expect(item.parentKey === 'ITEM001').assertTrue();
    });

    // ================================================================
    // Test e: annotation → getters work for color/pageLabel/sortIndex/position
    // ================================================================
    it('annotation fromJSON → color/pageLabel/sortIndex/position readable', (): void => {
      let json: Record<string, Object> = {
        data: {
          key: 'ANNOT01', version: 1,
          itemType: 'annotation',
          annotationType: 'highlight',
          annotationAuthorName: 'user123',
          annotationText: 'important finding',
          annotationComment: 'review this',
          annotationColor: '#FFD700',
          annotationPageLabel: '3',
          annotationSortIndex: '00005',
          annotationPosition: '{"x":10,"y":20,"width":100,"height":20}',
          parentItem: 'ATTACH01',
        }
      };
      let item = new ItemModel();
      item.fromJSON(json);
      expect(item.isAnnotation()).assertTrue();
      expect(item.isRegularItem()).assertFalse();
      expect(item.annotationType === AnnotationTypeEnum.HIGHLIGHT).assertTrue();
      expect(item.annotationAuthorName === 'user123').assertTrue();
      expect(item.annotationText === 'important finding').assertTrue();
      expect(item.annotationComment === 'review this').assertTrue();
      // e: getter checks
      expect(item.annotationColor === '#FFD700').assertTrue();
      expect(item.annotationPageLabel === '3').assertTrue();
      expect(item.annotationSortIndex === '00005').assertTrue();
      expect(item.annotationPosition === '{"x":10,"y":20,"width":100,"height":20}').assertTrue();
      expect(item.parentKey === 'ATTACH01').assertTrue();
    });

    // ================================================================
    // Test f: toJSON roundtrip for journalArticle
    // ================================================================
    it('journalArticle fromJSON → toJSON → fields aligned', (): void => {
      let json: Record<string, Object> = {
        data: {
          key: 'ITEM_RT', version: 10,
          itemType: 'journalArticle',
          title: 'Roundtrip Test',
          date: '2024',
          DOI: '10.9999/rt',
          creators: [
            { creatorType: 'author', firstName: 'Alice', lastName: 'Smith' },
            { creatorType: 'editor', firstName: 'Bob', lastName: 'Jones' }
          ],
          tags: [{ tag: 'test', type: 0 }, { tag: 'roundtrip', type: 1 }],
          collections: ['C1', 'C2'],
          relations: { 'dc:relation': ['R1'], 'dc:replaces': ['R2'] },
        }
      };
      let item = new ItemModel();
      item.fromJSON(json);
      let out = item.toJSON('full');
      expect(out.key === 'ITEM_RT').assertTrue();
      expect(out.version === 10).assertTrue();
      expect(out.itemType === 'journalArticle').assertTrue();
      expect(out.creators!.length === 2).assertTrue();
      expect(out.tags!.length === 2).assertTrue();
      // extraFields carry title/date/DOI
      expect(out.extraFields !== undefined).assertTrue();
      expect(out.extraFields!['title'] === 'Roundtrip Test').assertTrue();
      expect(out.extraFields!['date'] === '2024').assertTrue();
      expect(out.extraFields!['DOI'] === '10.9999/rt').assertTrue();
    });

    // ================================================================
    // Test g: note fromJSON → isNote()===true, isRegularItem()===false
    // ================================================================
    it('note fromJSON → isNote()===true, isRegularItem()===false', (): void => {
      let json: Record<string, Object> = {
        data: {
          key: 'NOTE01', version: 1,
          itemType: 'note',
          note: '<p>Some <b>rich</b> note content</p>',
          title: 'My Note Title',
          parentItem: 'ITEM001',
        }
      };
      let item = new ItemModel();
      item.fromJSON(json);
      expect(item.isNote()).assertTrue();
      expect(item.isRegularItem()).assertFalse();
      expect(item.noteText === '<p>Some <b>rich</b> note content</p>').assertTrue();
      expect(item.displayTitle === 'My Note Title').assertTrue();
      expect(item.parentKey === 'ITEM001').assertTrue();
    });

    // ================================================================
    // Test h: unwrapped JSON (no data wrapper)
    // ================================================================
    it('unwrapped JSON → isRegularItem still works', (): void => {
      let json: Record<string, Object> = {
        key: 'NO_WRAP', version: 1,
        itemType: 'book',
        title: 'Understanding Deep Learning',
        date: '2023',
        publisher: 'MIT Press',
      };
      let item = new ItemModel();
      item.fromJSON(json);
      expect(item.isRegularItem()).assertTrue();
      expect(item.itemTypeName === 'book').assertTrue();
      let out = item.toJSON('full');
      expect(out.itemType === 'book').assertTrue();
    });

  });
}
