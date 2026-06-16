import { describe, it, expect } from '@ohos/hypium';
import { DownloadResult, UploadResult, UserCancelledException, LibraryVersionDecreaseError } from '../../main/ets/sync/SyncExceptions.ets';
import { SyncLocalState } from '../../main/ets/sync/SyncLocalState.ets';
import { SyncRunner, SyncStatus } from '../../main/ets/sync/SyncRunner.ets';

export default function () {
  describe('SyncExceptions', () => {
    it('UserCancelledException should default advanceToNextLibrary to false', () => {
      let e = new UserCancelledException();
      expect(e.advanceToNextLibrary).assertFalse();
      expect(e.name).assertEqual('UserCancelledException');
    });

    it('UserCancelledException should accept advanceToNextLibrary=true', () => {
      let e = new UserCancelledException(true);
      expect(e.advanceToNextLibrary).assertTrue();
    });

    it('LibraryVersionDecreaseError should store name and detail', () => {
      let e = new LibraryVersionDecreaseError('My Library', 'version went from 5 to 0');
      expect(e.libraryName).assertEqual('My Library');
      expect(e.name).assertEqual('LibraryVersionDecreaseError');
    });

    it('DownloadResult enum should match original values', () => {
      expect(DownloadResult.CONTINUE).assertEqual(1);
      expect(DownloadResult.LIBRARY_UNMODIFIED).assertEqual(4);
    });

    it('UploadResult enum should match original values', () => {
      expect(UploadResult.SUCCESS).assertEqual(1);
      expect(UploadResult.CANCEL).assertEqual(6);
    });
  });

  describe('SyncLocalState', () => {
    it('should start with null API key', async () => {
      let s = new SyncLocalState();
      expect(await s.getApiKey()).assertNull();
    });

    it('should store and retrieve API key', async () => {
      let s = new SyncLocalState();
      await s.setApiKey('test-key-123');
      expect(await s.getApiKey()).assertEqual('test-key-123');
    });

    it('sync queue: add and get objects to retry', async () => {
      let s = new SyncLocalState();
      await s.addToSyncQueue(1, 'item', ['KEY1', 'KEY2']);
      let all = await s.getAllObjectsInQueue(1, 'item');
      expect(all.length).assertEqual(2);
    });

    it('sync queue: remove', async () => {
      let s = new SyncLocalState();
      await s.addToSyncQueue(1, 'item', ['KEY1']);
      await s.removeFromSyncQueue(1, 'item', ['KEY1']);
      let all = await s.getAllObjectsInQueue(1, 'item');
      expect(all.length).assertEqual(0);
    });

    it('delete log: add and get', async () => {
      let s = new SyncLocalState();
      await s.addToDeleteLog(1, 'item', ['DEL1', 'DEL2']);
      let deleted = await s.getDeleted(1, 'item');
      expect(deleted.length).assertEqual(2);
    });

    it('cache: save and retrieve', async () => {
      let s = new SyncLocalState();
      await s.saveCacheObjects(1, 'item', [{ key: 'C1', title: 'Test' }]);
      let obj = await s.getCacheObject(1, 'item', 'C1');
      expect(obj !== null).assertTrue();
      expect(obj!['title'] as string).assertEqual('Test');
    });

    it('last sync timestamp', async () => {
      let s = new SyncLocalState();
      expect(s.getLastSyncTime()).assertNull();
      await s.updateLastSyncTime();
      expect(s.getLastSyncTime() !== null).assertTrue();
    });
  });

  describe('SyncRunner', () => {
    it('should start in idle state', () => {
      let runner = new SyncRunner('https://api.example.org');
      expect(runner.syncStatus.state).assertEqual('idle');
    });

    it('should start and stop auto-sync without error', () => {
      let runner = new SyncRunner('https://api.example.org');
      runner.startAutoSync(3600);
      runner.stopAutoSync();
      expect(runner.syncStatus.state).assertEqual('idle');
    });
  });
}
