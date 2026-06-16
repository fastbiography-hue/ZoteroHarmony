# Zotero Desktop Parity Plan

This project targets a native HarmonyOS implementation of Zotero Desktop, not
only a visual clone. The reference baseline is the upstream Zotero repository,
especially:

- `chrome/content/zotero/zoteroPane.xhtml`
- `chrome/content/zotero/collectionTree.jsx`
- `chrome/content/zotero/itemTree.jsx`
- `chrome/content/zotero/itemTreeColumns.jsx`
- `chrome/content/zotero/elements/`
- `chrome/content/zotero/reader.xhtml`
- `chrome/content/zotero-platform/{mac,win,unix}/`
- `chrome/skin/default/zotero/`

## Desktop Shell

| Area | Zotero Desktop Behavior | Harmony Target | Current Status |
| --- | --- | --- | --- |
| Library workbench | Three panes: collections/tags, item tree, context item pane | Pane-first ArkUI workspace with collapsible/stacked adaptation | Partial |
| Toolbar commands | New item, collection, note, attachment, identifier lookup, sync, advanced search | Command registry plus ArkUI toolbar/menu surfaces | Missing |
| Menus and shortcuts | Platform-specific accel keys and native menu conventions | Harmony keyboard shortcuts and command routing | Missing |
| Tabs | Library and reader tabs with overflow menu | Tab manager and reader/library tab switching | Partial scaffold |
| Status/progress | Sync status, progress queue, error panels | Progress queue UI and sync diagnostics | Partial |

## Library Data

| Area | Zotero Desktop Behavior | Harmony Target | Current Status |
| --- | --- | --- | --- |
| Collections tree | Libraries, groups, feeds, saved searches, trash, duplicates, unfiled | Real data source from local DB and sync state | DB-backed baseline |
| Tag selector | Filter by colored/automatic tags with view settings | Left pane tag selector below collections | Missing |
| Item tree | Virtualized sortable columns, quick search, multi-select, row context menu | Virtualized ArkUI table with sorting/filtering/selection | DB-backed baseline |
| Item details | Type-specific fields, creators, tags, attachments, notes, related, duplicates | Context pane matching Zotero item pane sections | Partial |
| Drag and drop | Move items between collections, attach files, reorder relations | ArkUI drag/drop providers with command actions | Partial scaffold |

## Core Features

| Area | Zotero Desktop Behavior | Harmony Target | Current Status |
| --- | --- | --- | --- |
| Sync | Incremental data/file sync with conflict handling | Full data and file sync with visible conflict/progress UI | Partial |
| Attachments | Linked/imported files, URL attachments, rename rules | File picker, storage, preview/open, rename preview | Partial |
| Notes | Rich note editor and child notes | Native note editor with item linkage | Partial scaffold |
| Reader | PDF/EPUB reader, annotations, sidebar, tabs | Native reader with annotation editing and navigation | Partial |
| Citation | CSL/citeproc rendering, bibliography dialog, Quick Copy | Bundled CSL locales/styles and citeproc-compatible engine | Stub fallback |
| Import/export | BibTeX/RIS/CSL JSON, folder import, clipboard import | Import wizard, preview, conflict/error reporting | Partial |
| Search | Quick search, advanced search, saved searches, full text | Unified search data source with saved search persistence | Partial |
| Duplicate merge | Duplicate detection and merge UI | Merge workflow backed by item relations/data | Partial |
| Feeds | Feed subscription, feed items, settings | Feed UI and sync with local DB | Partial |
| Preferences | General, sync, cite, export, advanced | Native settings pages mapped to Zotero prefs | Missing |

## Platform Advantages To Preserve

| Platform | Zotero Advantage | Harmony Adaptation |
| --- | --- | --- |
| macOS | Compact source list, focus ring conventions, refined tab/toolbar spacing | Sidebar source-list density, subtle selection, gesture-friendly spacing |
| Windows | Clear item pane density, explicit toolbar affordances, familiar list controls | High-contrast panes, obvious buttons, keyboard-first workflows |
| Linux | GTK-like explicit borders, robust tab and preference rendering | Strong pane separators, predictable controls, low visual ambiguity |

## Implementation Priority

1. Replace mock collection/item data with DB-backed view models.
2. Add a command registry equivalent to Zotero's commandset for toolbar, menus, and shortcuts.
3. Complete item pane sections: Info, Attachments, Notes, Tags, Related, Abstract.
4. Add tag selector and saved-search persistence.
5. Wire attachment open, note open, related item navigation, and reader tabs.
6. Replace citation stubs with bundled CSL/citeproc-compatible rendering.
7. Add preferences and import/export wizard parity.
8. Add platform-adaptive density/theme tokens and accessibility verification.
