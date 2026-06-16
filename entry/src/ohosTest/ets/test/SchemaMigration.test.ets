import { describe, it, expect } from '@ohos/hypium';
import { CORE_TABLES, SCHEMA_VERSION, migrate } from '../../main/ets/database/SchemaMigration.ets';

export default function () {
  describe('SchemaMigration', () => {
    it('SCHEMA_VERSION should be positive', () => {
      expect(SCHEMA_VERSION > 0).assertTrue();
    });

    it('CORE_TABLES should contain all required tables', () => {
      let sql = CORE_TABLES.join(' ');
      expect(sql.includes('CREATE TABLE IF NOT EXISTS items')).assertTrue();
      expect(sql.includes('CREATE TABLE IF NOT EXISTS collections')).assertTrue();
      expect(sql.includes('CREATE TABLE IF NOT EXISTS creators')).assertTrue();
      expect(sql.includes('CREATE TABLE IF NOT EXISTS itemCreators')).assertTrue();
      expect(sql.includes('CREATE TABLE IF NOT EXISTS itemData')).assertTrue();
      expect(sql.includes('CREATE TABLE IF NOT EXISTS itemTags')).assertTrue();
      expect(sql.includes('CREATE TABLE IF NOT EXISTS itemNotes')).assertTrue();
      expect(sql.includes('CREATE TABLE IF NOT EXISTS itemAttachments')).assertTrue();
      expect(sql.includes('CREATE TABLE IF NOT EXISTS libraries')).assertTrue();
      expect(sql.includes('CREATE TABLE IF NOT EXISTS collectionItems')).assertTrue();
      expect(sql.includes('CREATE TABLE IF NOT EXISTS savedSearches')).assertTrue();
      expect(sql.includes('CREATE TABLE IF NOT EXISTS savedSearchConditions')).assertTrue();
      expect(sql.includes('CREATE TABLE IF NOT EXISTS tags')).assertTrue();
      expect(sql.includes('CREATE TABLE IF NOT EXISTS deletedItems')).assertTrue();
      expect(sql.includes('CREATE TABLE IF NOT EXISTS groups')).assertTrue();
      expect(sql.includes('CREATE TABLE IF NOT EXISTS syncedSettings')).assertTrue();
      expect(sql.includes('CREATE TABLE IF NOT EXISTS version')).assertTrue();
    });

    it('migrate should not throw with mock DB', async () => {
      let executed: string[] = [];
      let mock = { executeSql: async (sql: string): Promise<void> => { executed.push(sql); } };
      await migrate(mock);
      expect(executed.length).assertEqual(CORE_TABLES.length + 1); // tables + version INSERT
      // Verify version INSERT
      let last = executed[executed.length - 1];
      expect(last.includes('version')).assertTrue();
    });

    it('each CREATE TABLE should include IF NOT EXISTS', () => {
      for (let i = 0; i < CORE_TABLES.length; i++) {
        expect(CORE_TABLES[i].includes('IF NOT EXISTS')).assertTrue();
      }
    });
  });
}
