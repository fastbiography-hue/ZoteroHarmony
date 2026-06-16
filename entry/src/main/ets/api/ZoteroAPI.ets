/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: syncAPIClient.js — read endpoints
 *
 * ***** END LICENSE BLOCK *****
 */

import { HttpClient } from './HttpClient.ets';
import { PaginationHelper } from './PaginationHelper.ets';
import {
  LibraryType, ObjectType, KeyInfo, GroupVersions,
  SettingsResponse, DeletedResponse, VersionsResponse, SettingValue,
} from './ZoteroAPITypes.ets';

export class ZoteroAPI {
  private http: HttpClient;
  constructor(httpClient: HttpClient) { this.http = httpClient; }

  /** Build base path: /{type}s/{id}/{target} */
  private basePath(lt: LibraryType, ltid: number, target: string): string {
    return lt === 'publications'
      ? `/users/${ltid}/${lt}/${target}`
      : `/${lt}s/${ltid}/${target}`;
  }

  // ====== Auth ======
  async getKeyInfo(includeEmails: boolean = false): Promise<KeyInfo | null> {
    let suffix = includeEmails ? '?includeEmails=1' : '';
    let resp = await this.http.get<KeyInfo>(`/keys/current${suffix}`);
    return resp.statusCode === 403 ? null : resp.data;
  }

  // ====== Groups ======
  async getGroupVersions(userID: number): Promise<GroupVersions> {
    let resp = await this.http.get<Record<string, number>>(`/users/${userID}/groups?format=versions`);
    let result = new GroupVersions();
    if (resp.data) {
      let d = resp.data as Record<string, number>;
      let ks = Object.keys(d);
      for (let i = 0; i < ks.length; i++) {
        let gid = parseInt(ks[i]);
        result.set(gid, d[ks[i]]);
      }
    }
    return result;
  }

  async getGroups(userID: number): Promise<Record<string, Object>[]> {
    return PaginationHelper.fetchAllPages<Record<string, Object>>(`/users/${userID}/groups`, this.http);
  }

  async getGroup(groupID: number): Promise<Record<string, Object> | null> {
    let resp = await this.http.get<Record<string, Object>>(`/groups/${groupID}`);
    return resp.statusCode === 404 ? null : resp.data;
  }

  // ====== Settings ======
  async getSettings(lt: LibraryType, ltid: number, since?: number): Promise<SettingsResponse | null> {
    let url = this.basePath(lt, ltid, 'settings');
    if (since !== undefined) { url += `?since=${since}`; }
    let h: Record<string, string> = {};
    if (since !== undefined) { h['If-Modified-Since-Version'] = `${since}`; }
    let resp = await this.http.get<Record<string, SettingValue>>(url, h);
    if (resp.statusCode === 304 || !resp.data) { return null; }
    return { libraryVersion: resp.libraryVersion, settings: resp.data };
  }

  // ====== Versions ======
  async getVersions(lt: LibraryType, ltid: number, ot: ObjectType, since?: number, topOnly: boolean = false): Promise<VersionsResponse | null> {
    let plural = ot === 'item' ? 'items' : (ot === 'collection' ? 'collections' : 'searches');
    let url = this.basePath(lt, ltid, plural + (topOnly ? '/top' : ''));
    url += '?format=versions';
    if (since !== undefined) { url += `&since=${since}`; }
    if (ot === 'item') { url += '&includeTrashed=1'; }
    let resp = await this.http.get<Record<string, number>>(url);
    if (resp.statusCode === 304) { return null; }
    return { libraryVersion: resp.libraryVersion, versions: resp.data ?? ({} as Record<string, number>) };
  }

  // ====== Deletions ======
  async getDeleted(lt: LibraryType, ltid: number, since: number): Promise<DeletedResponse | null> {
    let url = `${this.basePath(lt, ltid, 'deleted')}?since=${since}`;
    let resp = await this.http.get<Record<string, string[]>>(url);
    if (resp.statusCode === 409) { return null; }
    return { libraryVersion: resp.libraryVersion, deleted: resp.data ?? ({} as Record<string, string[]>) };
  }

  // ====== Download ======
  async downloadObjects<T extends Record<string, Object>>(lt: LibraryType, ltid: number, ot: ObjectType, keys: string[]): Promise<T[]> {
    if (keys.length === 0) { return []; }
    let plural = ot === 'item' ? 'items' : (ot === 'collection' ? 'collections' : 'searches');
    let url = `${this.basePath(lt, ltid, plural)}?${ot}Key=${encodeURIComponent(keys.join(','))}`;
    if (ot === 'item') { url += '&includeTrashed=1'; }
    let resp = await this.http.get<T[]>(url);
    if (!resp.data) { return []; }
    return Array.isArray(resp.data) ? resp.data : [resp.data as T];
  }

  getHttp(): HttpClient { return this.http; }
}
