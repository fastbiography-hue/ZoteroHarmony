/*
 * Pure helpers for ItemDetailsForm — creator/tag dirty detection.
 * Extracted from ItemDetailsForm.ets so tests can import without
 * pulling in the @Component struct.
 */

import { ZoteroCreator, ZoteroTag } from '../../model/ItemTypes.ets';

export function creatorsToJson(creators: ZoteroCreator[]): string {
  let arr: Record<string, string>[] = [];
  for (let i = 0; i < creators.length; i++) {
    let entry: Record<string, string> = {
      ct: creators[i].creatorType,
      fn: creators[i].firstName,
      ln: creators[i].lastName,
      fm: `${creators[i].fieldMode}`,
    };
    if ((creators[i].name ?? '').length > 0) {
      entry['nm'] = creators[i].name!;
    }
    arr.push(entry);
  }
  return JSON.stringify(arr);
}

export function creatorsJsonEqual(jsonA: string, creatorsB: ZoteroCreator[]): boolean {
  return jsonA === creatorsToJson(creatorsB);
}

export function tagsToJson(tags: ZoteroTag[]): string {
  let arr: Record<string, string>[] = [];
  for (let i = 0; i < tags.length; i++) {
    arr.push({ tg: tags[i].tag, tp: `${tags[i].type}` });
  }
  return JSON.stringify(arr);
}

export function tagsJsonEqual(jsonA: string, tagsB: ZoteroTag[]): boolean {
  return jsonA === tagsToJson(tagsB);
}
