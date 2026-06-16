/*
 * File storage sync request model.
 */

export type StorageOperation = 'download' | 'upload';

export interface StorageRequest {
  itemID: number;
  itemKey: string;
  operation: StorageOperation;
  linkMode: number;
  path: string;
  contentType: string;
}
