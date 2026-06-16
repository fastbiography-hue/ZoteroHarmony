/*
 * Visual tokens for the Zotero Harmony workspace.
 *
 * The palette follows Zotero Desktop's restrained, pane-based interface while
 * adapting contrast, touch targets, and spacing for ArkUI.
 */

export class ZHColor {
  static readonly BRAND: string = '#B4282E';
  static readonly BRAND_DARK: string = '#8F1F24';
  static readonly BRAND_SOFT: string = '#F8E9EA';
  static readonly ACCENT: string = '#2F6FED';
  static readonly SUCCESS: string = '#2F8F46';
  static readonly WARNING: string = '#B7791F';

  static readonly SURFACE: string = '#FFFFFF';
  static readonly SURFACE_ALT: string = '#F6F7F9';
  static readonly SURFACE_SIDEBAR: string = '#F1F3F6';
  static readonly SURFACE_RAISED: string = '#FBFCFD';
  static readonly HOVER: string = '#EEF2F7';
  static readonly SELECTED: string = '#EAF1FF';
  static readonly SELECTED_STRONG: string = '#D7E4FF';

  static readonly TEXT: string = '#20242A';
  static readonly TEXT_MUTED: string = '#68717D';
  static readonly TEXT_SUBTLE: string = '#8C96A3';
  static readonly TEXT_INVERSE: string = '#FFFFFF';

  static readonly BORDER: string = '#D9DEE6';
  static readonly BORDER_SOFT: string = '#E8ECF2';
  static readonly TRANSPARENT: string = '#00000000';
}

export class ZHMetric {
  static readonly TOOLBAR_HEIGHT: number = 52;
  static readonly STATUS_HEIGHT: number = 34;
  static readonly ROW_HEIGHT: number = 38;
  static readonly HEADER_HEIGHT: number = 32;
  static readonly RADIUS_SMALL: number = 6;
  static readonly RADIUS_MEDIUM: number = 8;
  static readonly HIT_TARGET: number = 40;
}
