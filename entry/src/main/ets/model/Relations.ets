/*
 * Relations — predicate→object triple utility functions.
 * Extracted from DataObject.ets to keep files under 200 lines.
 * Ref: dataObject.js:323-488
 */

/**
 * Core relation storage type: flat array of [predicate, object] tuples.
 * Ref: dataObject.js:59  this._relations = []
 */
export type RelationTupleArray = Array<[string, string]>;

export class RelationUtils {
  /**
   * Convert flat tuple array to Record< predicate, object[] >.
   * Ref: dataObject.js:323-337
   */
  static toRecord(relations: RelationTupleArray): Record<string, string[]> {
    let result: Record<string, string[]> = {};
    for (let i = 0; i < relations.length; i++) {
      let p = relations[i][0];
      if (!result[p]) {
        result[p] = [];
      }
      result[p].push(relations[i][1]);
    }
    return result;
  }

  /**
   * Get objects for a specific predicate.
   * Ref: dataObject.js:345-363
   */
  static getByPredicate(relations: RelationTupleArray, predicate: string): string[] {
    let result: string[] = [];
    for (let i = 0; i < relations.length; i++) {
      if (relations[i][0] === predicate) {
        result.push(relations[i][1]);
      }
    }
    return result;
  }

  /**
   * Add relation. Returns true if added, false if already present.
   * Ref: dataObject.js:369-392
   */
  static add(relations: RelationTupleArray, predicate: string, object: string): boolean {
    for (let i = 0; i < relations.length; i++) {
      if (relations[i][0] === predicate && relations[i][1] === object) {
        return false;
      }
    }
    relations.push([predicate, object]);
    return true;
  }

  /**
   * Remove relation. Returns true if removed.
   * Ref: dataObject.js:408-426
   */
  static remove(relations: RelationTupleArray, predicate: string, object: string): boolean {
    for (let i = 0; i < relations.length; i++) {
      if (relations[i][0] === predicate && relations[i][1] === object) {
        relations.splice(i, 1);
        return true;
      }
    }
    return false;
  }

  /**
   * Check existence.
   * Ref: dataObject.js:395-405
   */
  static has(relations: RelationTupleArray, predicate: string, object: string): boolean {
    for (let i = 0; i < relations.length; i++) {
      if (relations[i][0] === predicate && relations[i][1] === object) {
        return true;
      }
    }
    return false;
  }

  /**
   * Replace all relations from a Record.
   * Ref: dataObject.js:435-488
   */
  static setFromRecord(
    relations: RelationTupleArray,
    newRelations: Record<string, string[]>
  ): void {
    relations.length = 0; // clear
    let keys = Object.keys(newRelations);
    for (let ki = 0; ki < keys.length; ki++) {
      let predicate = keys[ki];
      let objects = newRelations[predicate];
      for (let oi = 0; oi < objects.length; oi++) {
        relations.push([predicate, objects[oi]]);
      }
    }
  }
}
