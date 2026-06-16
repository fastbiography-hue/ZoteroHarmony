# Runtime Smoke Test — Zotero Sync Bootstrap

## Prerequisites

- DevEco Studio with HarmonyOS Emulator or device
- HAP built and installed successfully
- A valid Zotero API Key from https://www.zotero.org/settings/keys

## 1. Compilation & Launch

- [ ] `hvigorw assembleHap` succeeds (CompileArkTS: 0 errors)
- [ ] App launches without crash
- [ ] MainPage renders with toolbar, collection tree, empty item list

## 2. Login / Connect

1. Tap **Connect** in the footer
2. LoginPage appears
3. Enter a valid Zotero API Key
4. Tap **Connect**
5. If key is valid → returns to MainPage
   - [ ] Footer changes from "Not connected" to "All synced" or "Ready to sync"
   - [ ] Green dot appears in footer
   - [ ] Sync button is enabled
6. If key is invalid → error message shown on LoginPage
   - [ ] "Invalid API Key" message appears

## 3. First Sync

1. Tap **Sync** in the footer
2. Footer status changes:
   - [ ] "Checking libraries" appears
   - [ ] Then "Syncing library" / "Downloading changes"
3. On success:
   - [ ] Footer shows "Sync complete" or "All synced"
   - [ ] ItemTree reloads and shows items from Zotero library
   - [ ] Item titles / creators / dates are visible
4. On failure:
   - [ ] Error message shown in footer (e.g. "Invalid API key")
   - [ ] App does not crash
   - [ ] Previous items (if any) remain visible

## 4. Edit & Pending State

1. Select a regular item (not note/attachment)
2. Change the **title** field
3. Tap **Save**
   - [ ] Orange ● dot appears next to item in ItemTree
   - [ ] Footer shows "1 changes pending"
   - [ ] ItemPane shows "Saved locally, pending sync"
4. Select a note child item
5. Edit the note title or body
6. Tap **Save Note**
   - [ ] Pending count increases

## 5. Upload Sync

1. Tap **Sync**
2. On success:
   - [ ] Footer shows "Sync complete"
   - [ ] Pending dots disappear from ItemTree
   - [ ] Footer shows "All synced"
3. Verify on Zotero Web Library that the edited item reflects changes

## 6. P0 Workflow — New Item

- [ ] Tap top **+**
- [ ] Select **Book** type
- [ ] Enter a title
- [ ] Tap **Create**
- [ ] While creating: button shows "Creating…", disabled
- [ ] Cannot double-click to create duplicates
- [ ] Dialog closes
- [ ] New item appears in tree and is selected
- [ ] Right pane shows title in details
- [ ] Footer shows "1 changes pending"

## 7. P0 Workflow — New Collection

- [ ] Tap left LIBRARY **+**
- [ ] Enter a name
- [ ] Tap **Create**
- [ ] While saving: button shows "Saving…", disabled
- [ ] New collection appears in left tree and is selected
- [ ] Middle item list is empty (or shows collection items)
- [ ] Footer shows pending changes

## 8. P0 Workflow — Add by Identifier

- [ ] Tap **ID**
- [ ] Enter `10.1234/test` (DOI), `978-3-16-148410-0` (ISBN) — one per line
- [ ] Tap **Add**
- [ ] While adding: button shows "Adding…", disabled
- [ ] At least one item created and selected
- [ ] DOI/ISBN field written correctly
- [ ] Empty input or invalid text → "No valid identifiers found"

## 9. Failure Behavior

- [ ] New Item fails → dialog stays open, shows "Failed to create item"
- [ ] Collection save fails → dialog stays open, shows "Failed to save collection"
- [ ] Add Identifier fails → dialog stays open, shows "Failed to add identifier"
- [ ] Error text is red, does not contain API key

## 10. Edge Cases

- [ ] App restart preserves login state (footer shows "All synced")
- [ ] App works without login (local-only mode, footer shows "Not connected")
- [ ] Connection error during sync shows readable error message
- [ ] Rapid double-tap Sync does not crash
- [ ] Connect then immediately tap Sync — does NOT show "API key not set"
- [ ] App cold start: tap Sync immediately — does NOT show "API key not set"
- [ ] Footer shows "Initializing account…" during auth, Sync button disabled

## Notes

- API Key is stored in `preferences` and **never** printed to logs
- HAP is **not** committed to the repository
- Warnings (getContext deprecated, pushUrl deprecated, etc.) are not addressed in this phase
