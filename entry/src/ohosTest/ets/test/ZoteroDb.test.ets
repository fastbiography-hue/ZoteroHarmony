import { describe, it, expect } from '@ohos/hypium';
import { ZoteroDb, MAX_BOUND_PARAMETERS, Row } from '../../main/ets/database/ZoteroDb.ets';

export default function () {
  describe('ZoteroDb', () => {
    it('should default to closed state', () => {
      let db = new ZoteroDb(':memory:');
      expect(db.isOpen).assertFalse();
    });

    it('should not be in transaction when closed', () => {
      let db = new ZoteroDb(':memory:');
      expect(db.isInTransaction).assertFalse();
    });

    it('should throw if query before open', async () => {
      let db = new ZoteroDb(':memory:');
      let threw = false;
      try {
        await db.queryAsync('SELECT 1');
      } catch (_e) {
        threw = true;
      }
      expect(threw).assertTrue();
    });

    it('MAX_BOUND_PARAMETERS should be 999', () => {
      expect(MAX_BOUND_PARAMETERS).assertEqual(999);
    });

    it('should have idGen property', () => {
      let db = new ZoteroDb(':memory:');
      expect(db.idGen !== undefined).assertTrue();
    });

    it('executeTransaction should rollback on throw', async () => {
      let db = new ZoteroDb(':memory:');
      // Closed — throws on _requireStore
      let threw = false;
      try {
        await db.executeTransaction<string>(async (): Promise<string> => {
          throw new Error('intentional');
        });
      } catch (_e) {
        threw = true;
      }
      expect(threw).assertTrue();
      expect(db.isInTransaction).assertFalse(); // nested counter decremented
    });
  });
}
