/*
 * Pure helpers for attachment metadata draft dirty detection.
 * Extracted from ItemPaneView.ets so tests can import without
 * pulling in the @Component struct.
 */

export interface AttachmentDraftSnapshot {
  title: string;
  contentType: string;
  path: string;
  url: string;
}

export function attachmentDraftDirty(
  initial: AttachmentDraftSnapshot,
  current: AttachmentDraftSnapshot
): boolean {
  return initial.title !== current.title ||
    initial.contentType !== current.contentType ||
    initial.path !== current.path ||
    initial.url !== current.url;
}
