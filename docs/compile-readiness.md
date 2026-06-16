# DevEco Studio Compile-readiness

## Current Status

The project has **not yet been compiled in DevEco Studio**.  No HAP has been generated.

Current phase goal: **source-level feature closure** (P0 Alpha).

The codebase focuses on:
- Zotero Web API v3 download/upload
- Local item editing with SQLite-backed syncQueue/syncDeleteLog
- ItemTree parent-child hierarchy
- ItemPane edit forms (regular/note/attachment)
- Pending sync visibility

## Before First Compilation

### 1. Helper Import Separation

Pure helper functions have been extracted from `@Component` files into
`entry/src/main/ets/ui/helpers/`:

- `ItemDetailsHelpers.ets` — creator/tag JSON comparison
- `AttachmentDraftHelpers.ets` — attachment draft dirty detection
- `ItemTreeRowHelpers.ets` — row flattening, pending flag, parent key collection

Tests import from these helper files, not from UI component files.

### 2. @Watch / @Prop / @Link Checks

- `ItemTree.ets`: `@Watch('reload')` on collectionKey/filterText/revision/viewMode; `@Watch('_onPendingSyncChanged')` on pendingSyncRevision
- `ItemDetailsForm.ets`: `@Watch('_onItemSwitch')` on itemKey; `@Prop item` (not @Link)
- `ItemPaneView.ets`: `@Link item` + `@Link selectedView`; `@Prop currentItemPendingSync`

### 3. ArkTS Interface Consistency

- `ZoteroCreator`: creatorType, firstName, lastName, fieldMode, name?
- `ZoteroTag`: tag, type
- `PendingSyncSummary`: 8 numeric fields
- `ItemTreeRowModel`: 14 fields including isPendingSync
- `AttachmentDraftSnapshot`: title, contentType, path, url

### 4. relationalStore Wrapper

`ZoteroDb.ets` wraps `@ohos.data.relationalStore`.  Verify `querySql` and
`executeSql` signatures match the expected ArkTS API.

### 5. ohosTest Imports

All test files import pure helpers from `../../main/ets/ui/helpers/` rather
than from `@Component` struct files.

### 6. No HAP / Signing Artifacts Committed

`.gitignore` excludes:
```
*.hap *.app *.hsp
*.p12 *.p7b *.cer *.keystore *.jks
**/build/
build/
hvigor/cache/
```

## After Successful Compilation

- HAP will be generated via DevEco Studio → Build → Build HAP(s)
- HAP **must NOT be committed** to this repository
- Signed releases published via GitHub Releases

## Remaining Compilation Risks

The following have NOT been verified and may produce DevEco Studio errors:

- **ArkTS decorator syntax** — @Watch/@Prop/@Link/@State ordering and usage
- **relationalStore wrapper types** — ZoteroDb.queryAsync return types
- **@State Map/Record reactivity** — Map<string, FieldDraft> may not trigger re-render
- **ohosTest import behavior** — Hypium may have restrictions on what can be imported
- **Route path / module path** — router.pushUrl paths need to match module configuration
- **HAP signing configuration** — requires DevEco Studio project setup (not in source)
