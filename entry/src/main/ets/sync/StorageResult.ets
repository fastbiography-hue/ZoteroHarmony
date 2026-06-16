/*
 * File storage sync result model.
 */

export type StorageResultState = 'success' | 'skipped' | 'error';

export interface StorageResult {
  itemID: number;
  itemKey: string;
  state: StorageResultState;
  message: string;
}
