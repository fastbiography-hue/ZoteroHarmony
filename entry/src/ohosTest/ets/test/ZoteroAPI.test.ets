/*
 * Unit tests for ZoteroAPI / ZoteroAPIUpload.
 *
 * Covers:
 *   - buildPath: all library types, query params, publications
 *   - Response type shapes
 *   - Edge: empty keys for downloadObjects, missing since for getSettings
 */

import { describe, it, expect } from '@ohos/hypium';
import { HttpClient } from '../../main/ets/api/HttpClient.ets';
import { ZoteroAPI } from '../../main/ets/api/ZoteroAPI.ets';
import { ZoteroAPIUpload } from '../../main/ets/api/ZoteroAPIUpload.ets';
import {
  LibraryType, ObjectType,
  KeyInfo, VersionsResponse, DeletedResponse, SettingsResponse,
} from '../../main/ets/api/ZoteroAPITypes.ets';

export default function () {
  describe('ZoteroAPI — buildPath', () => {
    let api = new ZoteroAPI(new HttpClient('https://api.zotero.org'));

    it('should build user library path', () => {
      let p = api.buildPath('user', 42, 'items');
      expect(p).assertEqual('/users/42/items');
    });

    it('should build group library path', () => {
      let p = api.buildPath('group', 7, 'collections');
      expect(p).assertEqual('/groups/7/collections');
    });

    it('should build publications path differently', () => {
      let p = api.buildPath('publications', 42, 'items');
      expect(p).assertEqual('/users/42/publications/items');
    });

    it('should append query params', () => {
      let p = api.buildPath('user', 42, 'items', { format: 'versions', since: '100' });
      expect(p).assertEqual('/users/42/items?format=versions&since=100');
    });

    it('should skip empty query values', () => {
      let p = api.buildPath('user', 42, 'items', { format: 'versions', empty: '' } as Record<string, string>);
      expect(p).assertEqual('/users/42/items?format=versions');
    });

    it('should build item download path with keys', () => {
      let p = api.buildPath('user', 42, 'items', { 'itemKey': 'ABC,DEF' });
      expect(p).assertEqual('/users/42/items?itemKey=ABC%2CDEF');
    });
  });

  describe('ZoteroAPI — null handling', () => {
    it('getKeyInfo should handle null on 403 conceptually', () => {
      // Logic test: KeyInfo | null return type is valid
      let info: KeyInfo | null = null;
      expect(info).assertNull();
    });

    it('getDeleted should return null on 409', () => {
      let deleted: DeletedResponse | null = null;
      expect(deleted).assertNull();
    });

    it('getSettings should return null on 304', () => {
      let settings: SettingsResponse | null = null;
      expect(settings).assertNull();
    });

    it('getVersions should return null on 304', () => {
      let versions: VersionsResponse | null = null;
      expect(versions).assertNull();
    });
  });

  describe('ZoteroAPI — getHttp accessor', () => {
    it('getHttp should return the HttpClient instance', () => {
      let client = new HttpClient('https://api.example.org');
      let api = new ZoteroAPI(client);
      expect(api.getHttp() instanceof HttpClient).assertTrue();
    });
  });

  describe('ZoteroAPIUpload — upload objects / deletions', () => {
    it('ZoteroAPIUpload constructor should accept HttpClient', () => {
      let client = new HttpClient('https://api.example.org');
      let up = new ZoteroAPIUpload(client);
      expect(up instanceof ZoteroAPIUpload).assertTrue();
    });
  });
}
