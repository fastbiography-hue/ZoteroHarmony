import { describe, it, expect } from '@ohos/hypium';
import { IdGenerator } from '../../main/ets/database/IdGenerator.ets';

export default function () {
  describe('IdGenerator', () => {
    it('should throw if get() called before init()', () => {
      let gen = new IdGenerator();
      let threw = false;
      try { gen.get('items'); } catch (_e) { threw = true; }
      expect(threw).assertTrue();
    });

    it('should return sequential IDs after init', async () => {
      let gen = new IdGenerator();
      let fakeMax = async (_t: string): Promise<number> => 0;
      await gen.init(fakeMax);
      expect(gen.get('items')).assertEqual(1);
      expect(gen.get('items')).assertEqual(2);
      expect(gen.get('items')).assertEqual(3);
    });

    it('should track tables independently', async () => {
      let gen = new IdGenerator();
      let fakeMax = async (_t: string): Promise<number> => 99;
      await gen.init(fakeMax);
      expect(gen.get('collections')).assertEqual(100);
      expect(gen.get('tags')).assertEqual(100);
      expect(gen.get('collections')).assertEqual(101);
    });

    it('set() should override next ID', () => {
      let gen = new IdGenerator();
      gen.set('items', 5000);
      expect(gen.peek('items')).assertEqual(5000);
      expect(gen.get('items')).assertEqual(5000);
      expect(gen.get('items')).assertEqual(5001);
    });

    it('clear() should reset all', () => {
      let gen = new IdGenerator();
      gen.set('items', 100);
      gen.clear();
      expect(gen.peek('items')).assertEqual(0);
    });
  });
}
