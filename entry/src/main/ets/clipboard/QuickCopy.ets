/*
 * Quick Copy service.
 *
 * Uses HarmonyOS system pasteboard for Zotero citation/bibliography output.
 */

import { pasteboard } from '@kit.BasicServicesKit';

export class QuickCopy {
  static async copyText(text: string): Promise<void> {
    let data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    let systemPasteboard = pasteboard.getSystemPasteboard();
    await systemPasteboard.setData(data);
  }

  static async readText(): Promise<string> {
    let systemPasteboard = pasteboard.getSystemPasteboard();
    let data = await systemPasteboard.getData();
    return data.getPrimaryText();
  }
}
