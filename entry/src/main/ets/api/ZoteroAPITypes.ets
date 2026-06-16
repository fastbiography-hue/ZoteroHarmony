/*
 * Shared response types for ZoteroAPI / ZoteroAPIUpload.
 * Ref: syncAPIClient.js
 */

export type LibraryType = 'user' | 'group' | 'publications';
export type ObjectType = 'item' | 'collection' | 'search';

/** GET keys/current response. Ref: syncAPIClient.js:53-68 */
export interface KeyInfo {
  userID: number;
  username: string;
  displayName: string;
  access: Record<string, Object>;
  emails?: string[];
}

/** Groups version map entry. */
export interface GroupVersionEntry {
  groupId: number;
  version: number;
}

/** Groups version response: { groupId: version }. */
export class GroupVersions extends Map<number, number> {}

/** Single setting value. */
export interface SettingValue {
  value: string;
  version: number;
}

/** Settings response. Ref: syncAPIClient.js:140-143 */
export interface SettingsResponse {
  libraryVersion: number;
  settings: Record<string, SettingValue>;
}

/** Deleted objects response. Ref: syncAPIClient.js:164-167 */
export interface DeletedResponse {
  libraryVersion: number;
  deleted: Record<string, string[]>;
}

/** Versions response. Ref: syncAPIClient.js:249-252 */
export interface VersionsResponse {
  libraryVersion: number;
  versions: Record<string, number>;
}

/** One failed upload entry. */
export interface FailedUploadEntry {
  code: number;
  message: string;
  data?: Record<string, Object>;
}

/** Upload results per batch. Ref: syncAPIClient.js:423-426 */
export interface UploadResults {
  successful: Record<string, Object>[];
  unchanged: string[];
  failed: FailedUploadEntry[];
}

/** Upload response wrapper. */
export interface UploadResponse {
  libraryVersion: number;
  results: UploadResults;
}
