/*
 * ***** BEGIN LICENSE BLOCK *****
 *
 * Copyright © 2024 Zotero Community
 * Ref: reader/ submodule — shared reader types
 *
 * ***** END LICENSE BLOCK *****
 */

/** Annotation types matching Zotero's itemAnnotations schema. */
export type AnnotationType = 'highlight' | 'underline' | 'note' | 'image' | 'ink';

/** Color palette for annotations. Ref: reader toolbar defaults. */
export const ANNOTATION_COLORS: string[] = [
  '#FFD700', // Yellow (default highlight)
  '#FF6B6B', // Red
  '#4ECDC4', // Teal
  '#45B7D1', // Blue
  '#96CEB4', // Green
  '#FFEAA7', // Pale Yellow
  '#DDA0DD', // Plum
  '#FF8C00', // Orange
];

/** Position rectangle (fractional, 0..1). */
export interface AnnotationPosition {
  x: number;
  y: number;
  width: number;
  height: number;
}

/** One annotation on a PDF page. */
export interface PdfAnnotation {
  id: string;
  type: AnnotationType;
  pageIndex: number;
  position: AnnotationPosition;
  color: string;
  text?: string;       // For highlights/underlines
  comment?: string;    // User-added note
  authorName?: string;
  sortIndex: string;   // e.g. "00001|00005|00010"
  dateModified: string;
}

/** State of an open reader instance. */
export interface ReaderState {
  itemID: number;
  itemKey: string;
  title: string;
  filePath: string;         // local path to PDF
  totalPages: number;
  currentPage: number;
  annotations: PdfAnnotation[];
  /** Serialized reader UI state (sidebar open, zoom, etc.) */
  uiState: string;           // JSON string
}
