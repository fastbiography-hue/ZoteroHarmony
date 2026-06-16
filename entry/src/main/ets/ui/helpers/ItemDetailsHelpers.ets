/*
 * Pure helpers for creator/tag dirty detection.
 * Uses string serialisation to avoid ArkTS object-literal restrictions.
 */

import { ZoteroCreator, ZoteroTag } from '../../model/ItemTypes.ets';

const SEP = '';

export function creatorsToJson(creators: ZoteroCreator[]): string {
  let parts: string[] = [];
  for (let i = 0; i < creators.length; i++) {
    let c = creators[i];
    parts.push([
      c.creatorType, c.firstName, c.lastName,
      `${c.fieldMode}`, c.name ?? ''
    ].join(SEP));
  }
  return parts.join('');
}

export function creatorsJsonEqual(jsonA: string, creatorsB: ZoteroCreator[]): boolean {
  return jsonA === creatorsToJson(creatorsB);
}

export function tagsToJson(tags: ZoteroTag[]): string {
  let parts: string[] = [];
  for (let i = 0; i < tags.length; i++) {
    parts.push(`${tags[i].tag}${SEP}${tags[i].type}`);
  }
  return parts.join('');
}

export function tagsJsonEqual(jsonA: string, tagsB: ZoteroTag[]): boolean {
  return jsonA === tagsToJson(tagsB);
}
