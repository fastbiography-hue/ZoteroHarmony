/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: syncAPIClient.js:830-878  makeRequest / getHeaders
 *
 * ***** END LICENSE BLOCK *****
 */

import { http } from '@kit.NetworkKit';
import { ZoteroHttpError } from './ZoteroHttpError.ets';

/** HTTP response wrapper with typed body. */
export interface HttpResponse<T> {
  statusCode: number;
  data: T | null;
  libraryVersion: number;
  headers: Record<string, string>;
}

/**
 * Thin wrapper over @ohos.net.http for Zotero API calls.
 */
export class HttpClient {
  private baseURL: string;
  private apiKey: string;
  private apiVersion: string;
  private schemaVersion: number;

  constructor(
    baseURL: string, apiKey: string = '',
    apiVersion: string = '3', schemaVersion: number = 15
  ) {
    this.baseURL = baseURL.replace(/\/+$/, '');
    this.apiKey = apiKey;
    this.apiVersion = apiVersion;
    this.schemaVersion = schemaVersion;
  }

  setApiKey(key: string): void { this.apiKey = key; }

  // ==================================================================
  // request<T> — main entry point
  // ==================================================================

  async request<T>(
    method: http.RequestMethod, path: string,
    body?: string | null, extraHeaders?: Record<string, string>
  ): Promise<HttpResponse<T>> {
    let httpReq = http.createHttp();
    let response: http.HttpResponse | null = null;
    try {
      let url = `${this.baseURL}${path}`;
      let opts: http.HttpRequestOptions = {
        method: method,
        header: this._buildHeaders(extraHeaders),
        extraData: body ?? undefined,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 30000,
        readTimeout: 120000,
      };
      response = await httpReq.request(url, opts);

      let statusCode = response.responseCode;
      let bodyStr = (response.result as string) ?? '';
      let headers = this._parseHeaders(response);
      let libraryVersion = parseInt(headers['last-modified-version'] ?? '0');

      if (statusCode === 200 || statusCode === 204) {
        let data: T | null = bodyStr.length > 0 ? JSON.parse(bodyStr) as T : null;
        return { statusCode, data, libraryVersion, headers };
      }
      if (statusCode === 304) {
        return { statusCode, data: null, libraryVersion, headers };
      }
      throw this._statusToError(statusCode, bodyStr, headers);
    } finally {
      if (response === null) {
        // request threw before assignment; destroy is safe
      }
      httpReq.destroy();
    }
  }

  // ==================================================================
  // Convenience
  // ==================================================================

  async get<T>(path: string, headers?: Record<string, string>): Promise<HttpResponse<T>> {
    return this.request<T>(http.RequestMethod.GET, path, null, headers);
  }

  async post<T>(path: string, body: string, headers?: Record<string, string>): Promise<HttpResponse<T>> {
    return this.request<T>(http.RequestMethod.POST, path, body, headers);
  }

  async patch<T>(path: string, body: string, headers?: Record<string, string>): Promise<HttpResponse<T>> {
    return this.request<T>(http.RequestMethod.POST, path, body, headers);
  }

  async deleteRequest<T>(path: string, headers?: Record<string, string>): Promise<HttpResponse<T>> {
    return this.request<T>(http.RequestMethod.DELETE, path, null, headers);
  }

  // ==================================================================
  // Private
  // ==================================================================

  private _buildHeaders(extra?: Record<string, string>): Record<string, string> {
    let h: Record<string, string> = {
      'Content-Type': 'application/json',
      'Zotero-API-Version': this.apiVersion,
      'Zotero-Schema-Version': `${this.schemaVersion}`,
    };
    if (this.apiKey) {
      h['Authorization'] = `Bearer ${this.apiKey}`;
    }
    if (extra) {
      let keys = Object.keys(extra);
      for (let i = 0; i < keys.length; i++) { h[keys[i]] = extra[keys[i]]; }
    }
    return h;
  }

  private _parseHeaders(response: http.HttpResponse): Record<string, string> {
    let result: Record<string, string> = {};
    let rh = response.header as Record<string, string>;
    if (!rh) { return result; }
    let keys = Object.keys(rh);
    for (let i = 0; i < keys.length; i++) {
      result[keys[i].toLowerCase()] = rh[keys[i]];
    }
    return result;
  }

  private _statusToError(status: number, body: string, headers: Record<string, string>): ZoteroHttpError {
    let msg = this._extractErrorMessage(body);
    switch (status) {
      case 403: return ZoteroHttpError.unauthorized(msg);
      case 404: return ZoteroHttpError.notFound(msg);
      case 409: return ZoteroHttpError.conflict(msg);
      case 412: return ZoteroHttpError.precondition(msg);
      case 413: return ZoteroHttpError.payloadTooLarge(msg);
      case 429: {
        let ra = parseInt(headers['retry-after'] ?? '0');
        return ZoteroHttpError.rateLimited(ra > 0 ? ra : 30);
      }
      default:
        if (status >= 400 && status < 500) { return new ZoteroHttpError(status, msg); }
        if (status >= 500) { return new ZoteroHttpError(status, `Server error ${status}: ${msg}`); }
        return new ZoteroHttpError(status, `Unexpected status ${status}: ${msg}`);
    }
  }

  private _extractErrorMessage(body: string): string {
    if (!body) { return ''; }
    try {
      let parsed = JSON.parse(body) as Record<string, Object>;
      if (parsed['message']) { return parsed['message'] as string; }
      if (parsed['error']) { return parsed['error'] as string; }
    } catch (_e) { /* not JSON */ }
    return body.length > 200 ? body.substring(0, 200) : body;
  }
}
