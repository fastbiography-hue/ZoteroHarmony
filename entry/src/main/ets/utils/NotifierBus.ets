/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ported from Zotero Desktop (AGPL-3.0)
 * Original: chrome/content/zotero/xpcom/notifier.js
 *
 * ***** END LICENSE BLOCK *****
 */

import { emitter } from '@kit.BasicServicesKit';

/**
 * Callback type for event observers.
 * Ref: notifier.js:63  notify(event, type, ids, extraData)
 */
export type NotifierCallback = (ids: number[], extra?: Record<string, Object>) => void;

/**
 * Supported event types — subset of original notifier.js:33-56
 */
export const NOTIFIER_EVENTS: string[] = [
  'item-add', 'item-modify', 'item-delete',
  'collection-add', 'collection-modify', 'collection-delete',
  'sync-start', 'sync-finish', 'sync-error',
  'search-add', 'search-modify', 'search-delete',
];

/** Internal observer record. */
interface ObserverEntry {
  id: string;
  callback: NotifierCallback;
}

/**
 * Singleton event bus wrapping @ohos.events.emitter.
 *
 * Ref: notifier.js:28-110  registerObserver / unregisterObserver / trigger
 */
export class NotifierBus {
  private static instance: NotifierBus | null = null;
  private observers: Map<string, ObserverEntry> = new Map();

  private constructor() {
    // private — singleton
  }

  static getInstance(): NotifierBus {
    if (!NotifierBus.instance) {
      NotifierBus.instance = new NotifierBus();
    }
    return NotifierBus.instance;
  }

  /**
   * Register an event listener. Returns an observerID for later unregister().
   * Ref: notifier.js:68-105
   */
  register(
    eventType: string,
    callback: NotifierCallback,
    id?: string
  ): string {
    if (!NOTIFIER_EVENTS.includes(eventType)) {
      throw new Error(`Invalid event type '${eventType}'`);
    }
    let observerID = id ?? this._generateID();
    let entry: ObserverEntry = { id: observerID, callback };
    this.observers.set(observerID, entry);

    // Use emitter API for cross-component broadcast
    emitter.on(eventType, (data: emitter.EventData): void => {
      if (data && data.data) {
        let payload = data.data as Record<string, Object>;
        let ids: number[] = (payload['ids'] ?? []) as number[];
        let extra = payload['extra'] as Record<string, Object> | undefined;
        callback(ids, extra);
      }
    });

    return observerID;
  }

  /**
   * Unregister by observerID.
   * Ref: notifier.js:107-110
   */
  unregister(observerID: string): void {
    let entry = this.observers.get(observerID);
    if (entry) {
      emitter.off(this.observers.size, observerID);
      this.observers.delete(observerID);
    }
  }

  /**
   * Emit event to all registered listeners.
   * Ref: notifier.js:132-160  trigger
   */
  emit(eventType: string, ids: number[], extra?: Record<string, Object>): void {
    if (!NOTIFIER_EVENTS.includes(eventType)) {
      throw new Error(`Invalid event type '${eventType}'`);
    }
    let payload: emitter.EventData = {
      data: { ids: ids, extra: extra ?? {} },
    };
    emitter.emit({ eventId: eventType, priority: emitter.EventPriority.LOW }, payload);
  }

  /** Generate a random observer ID. Ref: notifier.js:79-91 */
  private _generateID(): string {
    let chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    let result = 'obs_';
    for (let i = 0; i < 6; i++) {
      result += chars.charAt(Math.floor(Math.random() * chars.length));
    }
    return result;
  }
}
