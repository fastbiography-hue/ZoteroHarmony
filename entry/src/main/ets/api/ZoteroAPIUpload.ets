/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: syncAPIClient.js:393-471  uploadObjects / uploadDeletions
 *
 * ***** END LICENSE BLOCK *****
 */

import { http } from '@kit.NetworkKit';
import { HttpClient } from './HttpClient.ets';
import { LibraryType, ObjectType, UploadResponse, UploadResults } from './ZoteroAPITypes.ets';

const PLURAL: Record<ObjectType, string> = {
  'item': 'items', 'collection': 'collections', 'search': 'searches',
};

/**
 * Upload-oriented API methods.
 * Ref: syncAPIClient.js:393-427  uploadObjects
 */
export class ZoteroAPIUpload {
  private http: HttpClient;

  constructor(httpClient: HttpClient) {
    this.http = httpClient;
  }

  async uploadObjects(
    libraryType: LibraryType, libraryTypeID: number,
    libraryVersion: number, objectType: ObjectType,
    objects: Record<string, Object>[]
  ): Promise<UploadResponse> {
    let target = PLURAL[objectType];
    let path = `/${libraryType}s/${libraryTypeID}/${target}`;
    let body = JSON.stringify(objects);
    let headers: Record<string, string> = {
      'If-Unmodified-Since-Version': `${libraryVersion}`,
    };
    let resp = await this.http.post<UploadResults>(path, body, headers);
    return {
      libraryVersion: resp.libraryVersion,
      results: resp.data ?? { successful: [], unchanged: [], failed: [] },
    };
  }

  async uploadDeletions(
    libraryType: LibraryType, libraryTypeID: number,
    libraryVersion: number, objectType: ObjectType, keys: string[]
  ): Promise<number> {
    let target = PLURAL[objectType];
    let queryKey = objectType === 'item' ? 'itemKey' : `${objectType}Key`;
    let path = `/${libraryType}s/${libraryTypeID}/${target}?${queryKey}=${encodeURIComponent(keys.join(','))}`;
    let headers: Record<string, string> = {
      'If-Unmodified-Since-Version': `${libraryVersion}`,
    };
    let resp = await this.http.deleteRequest<Record<string, Object>>(path, headers);
    return resp.libraryVersion;
  }
}
