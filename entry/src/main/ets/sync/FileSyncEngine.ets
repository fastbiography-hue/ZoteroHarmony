/*
 * Local file-sync queue coordinator.
 *
 * This is the bridge between Zotero attachment metadata and future ZFS/WebDAV
 * transfer implementations.
 */

import { LibraryRepository } from '../database/LibraryRepository.ets';
import { StorageRequest } from './StorageRequest.ets';
import { StorageResult } from './StorageResult.ets';
import { FileStorage } from '../utils/FileStorage.ets';
import { fileIo } from '@kit.CoreFileKit';

export class FileSyncEngine {
  private appContext: Context;
  private storage: FileStorage | null = null;

  constructor(appContext: Context) {
    this.appContext = appContext;
    let filesDir = this.appContext.filesDir ?? '';
    if (filesDir.length > 0) {
      this.storage = new FileStorage(filesDir);
    }
  }

  async runPending(): Promise<StorageResult[]> {
    let repo = new LibraryRepository();
    await repo.open(this.appContext);
    try {
      let requests = await repo.listPendingStorageRequests();
      let results: StorageResult[] = [];
      for (let i = 0; i < requests.length; i++) {
        let result = await this.processRequest(repo, requests[i]);
        results.push(result);
      }
      return results;
    } finally {
      await repo.close();
    }
  }

  private async processRequest(repo: LibraryRepository, request: StorageRequest): Promise<StorageResult> {
    await repo.updateAttachmentSyncState(request.itemID, 2);
    if (request.path.length === 0) {
      await repo.updateAttachmentSyncState(request.itemID, 3);
      return {
        itemID: request.itemID,
        itemKey: request.itemKey,
        state: 'error',
        message: 'Attachment path is empty',
      };
    }
    if (request.linkMode === 3 || request.path.startsWith('http://') || request.path.startsWith('https://')) {
      if (!this.storage) {
        await repo.updateAttachmentSyncState(request.itemID, 3);
        return {
          itemID: request.itemID,
          itemKey: request.itemKey,
          state: 'error',
          message: 'File storage directory is unavailable',
        };
      }
      try {
        let stored = await this.storage.downloadFile(request.path, request.itemKey, request.contentType);
        await repo.updateAttachmentPath(request.itemID, stored.localPath);
        await repo.updateAttachmentSyncState(request.itemID, 1);
        return {
          itemID: request.itemID,
          itemKey: request.itemKey,
          state: 'success',
          message: 'Downloaded attachment into local storage',
        };
      } catch (err) {
        await repo.updateAttachmentSyncState(request.itemID, 3);
        return {
          itemID: request.itemID,
          itemKey: request.itemKey,
          state: 'error',
          message: (err as Error).message ?? 'Failed to download attachment',
        };
      }
    }
    if (fileIo.accessSync(request.path)) {
      await repo.updateAttachmentSyncState(request.itemID, 1);
      return {
        itemID: request.itemID,
        itemKey: request.itemKey,
        state: 'success',
        message: 'Local attachment already available',
      };
    }
    await repo.updateAttachmentSyncState(request.itemID, 3);
    return {
      itemID: request.itemID,
      itemKey: request.itemKey,
      state: 'error',
      message: 'Binary attachment transfer backend is not configured yet',
    };
  }
}
