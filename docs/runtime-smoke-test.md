# Runtime Smoke Test — Zotero Sync Bootstrap

## Prerequisites

- DevEco Studio with HarmonyOS Emulator/device
- HAP built and installed successfully (CompileArkTS: 0 errors)
- Valid Zotero API Key from https://www.zotero.org/settings/keys

---

## A. App Launch

- [ ] App launches without crash
- [ ] MainPage renders: toolbar, collection tree (My Library), empty item list
- [ ] Footer shows "Not connected" (first launch) or "All synced" (restart with saved key)
- [ ] Theme toggle works (if supported)

## B. Connect + Sync

- [ ] Tap **Connect** in footer → LoginPage appears
- [ ] Enter valid Zotero API Key → tap **Connect**
- [ ] Returns to MainPage → footer changes to "All synced" or "Ready to sync"
- [ ] Invalid key → error message shown on LoginPage
- [ ] Tap **Sync**
- [ ] Footer shows "Checking libraries" → "Downloading changes" → "Sync complete"
- [ ] ItemTree reloads: Zotero library items appear

## C. New Collection

- [ ] Tap left LIBRARY **+**
- [ ] Dialog appears: "New Collection", name input
- [ ] Enter name, tap **Create**
- [ ] Button shows "Saving…", disabled
- [ ] Dialog closes, new collection appears in left tree, selected
- [ ] Footer shows "Collection created" (green), pending changes count
- [ ] Empty name → "Collection name is required" error

## D. New Item in Collection

- [ ] Select a collection in left tree
- [ ] Tap top **+**
- [ ] Dialog appears: type selector + title input
- [ ] Select **Book**, enter title, tap **Create**
- [ ] Button shows "Creating…", disabled
- [ ] Dialog closes, new item appears in center tree, selected
- [ ] Right pane shows title in details
- [ ] Footer shows "Item created" (green), pending changes

## E. Edit Title + Save

- [ ] Select a regular item in center tree
- [ ] Right pane → Info tab → change title field
- [ ] Tap **Save** (turns green "Saved locally, pending sync")
- [ ] ItemTree shows orange ● pending dot next to item

## F. Pending Dot + Upload

- [ ] Footer shows "1 changes pending"
- [ ] Tap **Sync**
- [ ] Sync completes → pending dot disappears
- [ ] Footer shows "All synced"

## G. Add Note

- [ ] Select a regular item
- [ ] Tap toolbar **Note** or row menu **Add note**
- [ ] Child note row appears under item (expand ▶ to see if collapsed)
- [ ] Tap note child → note editor opens (title + body)

## H. Add Attachment

- [ ] Select a regular item
- [ ] Tap row menu **Add attachment**
- [ ] Child attachment row appears under item
- [ ] Tap attachment child → attachment detail or reader opens

## I. Delete Item

- [ ] Select an item, tap **Delete** in right toolbar
- [ ] Item disappears from current view
- [ ] Switch to **Trash** view in left tree
- [ ] Deleted item appears in trash
- [ ] Footer shows "Moved to trash" (green)

## J. Restore Item

- [ ] In **Trash** view, select an item
- [ ] Tap **Restore**
- [ ] Item disappears from trash
- [ ] Switch to My Library → item is back
- [ ] Footer shows "Restored" (green)

## K. Add by Identifier

- [ ] Tap **ID** in toolbar
- [ ] Dialog appears: textarea for identifiers
- [ ] Enter `10.1234/test` (DOI), `978-3-16-148410-0` (ISBN) — one per line
- [ ] Tap **Add**
- [ ] Button shows "Adding…", disabled
- [ ] Items created and first one selected
- [ ] DOI/ISBN fields written to respective items
- [ ] Footer shows "N item(s) added" (green)

## L. Invalid Identifier

- [ ] Tap **ID** → enter empty input or "just some text"
- [ ] Tap **Add** → "No valid identifiers found" error

## M. Failure Behavior

- [ ] New Item fails → dialog stays open, red "Failed to create item"
- [ ] Collection save fails → dialog stays open, red "Failed to save collection"
- [ ] Add Identifier fails → dialog stays open, red "Failed to add identifier"
- [ ] Rapid double-click Create/Add does not create duplicates

## N. App Restart Auth State

- [ ] Close and reopen app
- [ ] Footer shows "All synced" (not "Not connected")
- [ ] Tap Sync immediately → does NOT show "API key not set"
- [ ] Footer shows "Initializing account…" briefly, then proceeds

---

## Notes

- API Key stored in preferences, never printed to logs
- HAP not committed to repository
- Warnings (getContext deprecated, etc.) not addressed in this phase
- No localization implemented yet (English only)
