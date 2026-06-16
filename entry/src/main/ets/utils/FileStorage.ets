/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: xpcom/storage/zfs.js + storageLocal.js — file download/storage
 * ArkTS: @ohos.file.fs + @ohos.net.http for download
 *
 * ***** END LICENSE BLOCK *****
 */

import { fileIo } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';

/** File metadata returned after download. */
export interface StoredFile {
  localPath: string;
  remoteKey: string;
  contentType: string;
  sizeBytes: number;
  md5Hash: string;
  mtime: number;
}

/** Base directory for Zotero storage within app sandbox. */
const ZOTERO_STORAGE_DIR = 'zotero/storage';

/**
 * Manages local file storage — download, verify, delete.
 *
 * Replaces: Mozilla nsIFile + IOUtils with @ohos.file.fs.
 * Ref: storageEngine.js download/upload flow
 */
export class FileStorage {
  private baseDir: string;

  constructor(appFilesDir: string) {
    this.baseDir = `${appFilesDir}/${ZOTERO_STORAGE_DIR}`;
  }

  /** Ensure the storage root directory exists. */
  async initialize(): Promise<void> {
    if (!fileIo.accessSync(this.baseDir)) {
      fileIo.mkdirSync(this.baseDir, true);
    }
  }

  /** Download a file from remote URL to local storage. */
  async downloadFile(
    remoteURL: string,
    remoteKey: string,
    contentType: string,
    apiKey: string = ''
  ): Promise<StoredFile> {
    let httpReq = http.createHttp();
    try {
      let itemDir = `${this.baseDir}/${remoteKey.substring(0, 8)}`;
      if (!fileIo.accessSync(itemDir)) {
        fileIo.mkdirSync(itemDir, true);
      }

      let localPath = `${itemDir}/${remoteKey}`;
      let headers: Record<string, string> = {};
      if (apiKey.length > 0) {
        headers['Authorization'] = `Bearer ${apiKey}`;
      }
      let response = await httpReq.request(remoteURL, {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 30000,
        readTimeout: 120000,
      });

      let data = response.result as ArrayBuffer;
      let file = fileIo.openSync(localPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY);
      fileIo.writeSync(file.fd, data);
      fileIo.closeSync(file);

      return {
        localPath, remoteKey, contentType,
        sizeBytes: data.byteLength,
        md5Hash: '',   // computed separately if needed
        mtime: Date.now(),
      };
    } finally {
      httpReq.destroy();
    }
  }

  /** Import a user-selected local file or URI into Zotero storage. */
  async importFile(
    sourceUri: string,
    remoteKey: string,
    contentType: string
  ): Promise<StoredFile> {
    let itemDir = `${this.baseDir}/${remoteKey.substring(0, 8)}`;
    if (!fileIo.accessSync(itemDir)) {
      fileIo.mkdirSync(itemDir, true);
    }
    let localPath = `${itemDir}/${remoteKey}`;
    fileIo.copyFileSync(sourceUri, localPath);
    let sizeBytes = 0;
    try {
      let stat = fileIo.statSync(localPath);
      sizeBytes = stat.size ?? 0;
    } catch (_err) {
      sizeBytes = 0;
    }
    return {
      localPath,
      remoteKey,
      contentType,
      sizeBytes,
      md5Hash: '',
      mtime: Date.now(),
    };
  }

  /** Check if a file exists locally. */
  fileExists(remoteKey: string): boolean {
    let itemDir = `${this.baseDir}/${remoteKey.substring(0, 8)}`;
    return fileIo.accessSync(`${itemDir}/${remoteKey}`);
  }

  /** Get absolute path to a stored file. */
  getLocalPath(remoteKey: string): string {
    return `${this.baseDir}/${remoteKey.substring(0, 8)}/${remoteKey}`;
  }

  /** Delete a stored file. */
  deleteFile(remoteKey: string): boolean {
    let path = this.getLocalPath(remoteKey);
    if (fileIo.accessSync(path)) {
      fileIo.unlinkSync(path);
      return true;
    }
    return false;
  }

  /** List all stored files. Returns absolute paths. */
  listFiles(): string[] {
    let result: string[] = [];
    try {
      let dirs = fileIo.listFileSync(this.baseDir);
      for (let i = 0; i < dirs.length; i++) {
        let subPath = `${this.baseDir}/${dirs[i]}`;
        let files = fileIo.listFileSync(subPath);
        for (let j = 0; j < files.length; j++) {
          result.push(`${subPath}/${files[j]}`);
        }
      }
    } catch (_e) { /* dir may not exist yet */ }
    return result;
  }
}
