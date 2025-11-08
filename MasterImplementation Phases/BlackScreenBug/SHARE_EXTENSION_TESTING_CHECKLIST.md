# Share Extension Testing Checklist

## Pre-Testing Setup

- [ ] Share Extension target added in Xcode (see `iOS_SHARE_EXTENSION_SETUP.md`)
- [ ] All files added to correct targets
- [ ] App Groups capability configured for both targets
- [ ] Build succeeds without errors
- [ ] App installs on device/simulator

## Test Scenarios

### 1. Share Text from Notes App

**Steps:**
1. Open **Notes** app on iOS
2. Create a new note with text: "This is a test note from Notes app"
3. Select the text
4. Tap **Share** button
5. Find and tap **Duru Notes** in the share sheet
6. (Optional) Add comment in the share extension
7. Tap **Post**
8. Extension should dismiss
9. Open **Duru Notes** app
10. Check inbox/notes list

**Expected Result:**
- ✅ New note created with title "This is a test note from Notes app"
- ✅ Body contains the shared text
- ✅ Metadata shows `source: share_extension`, `share_type: text`

---

### 2. Share URL from Safari

**Steps:**
1. Open **Safari** on iOS
2. Navigate to a website (e.g., https://flutter.dev)
3. Tap the **Share** button (square with arrow)
4. Find and tap **Duru Notes**
5. Tap **Post**
6. Extension dismisses
7. Open **Duru Notes** app

**Expected Result:**
- ✅ New note created with title matching website domain (e.g., "flutter.dev")
- ✅ Body contains markdown with the URL
- ✅ Format: `# [title]\n**Link**: [url]`
- ✅ Metadata shows `source: share_extension`, `share_type: url`

---

### 3. Share Image from Photos

**Steps:**
1. Open **Photos** app on iOS
2. Select any photo
3. Tap **Share** button
4. Find and tap **Duru Notes**
5. Tap **Post**
6. Extension dismisses
7. Open **Duru Notes** app

**Expected Result:**
- ✅ New note created with title "Shared Image"
- ✅ Body contains markdown image reference
- ✅ Image file saved to app group shared container
- ✅ Image appears in note (once attachment service processes it)
- ✅ Metadata shows `source: share_extension`, `share_type: image`

---

### 4. Share Multiple Items

**Steps:**
1. Open **Photos** app
2. Select multiple photos (2-3)
3. Tap **Share** button
4. Tap **Duru Notes**
5. Tap **Post**
6. Open **Duru Notes** app

**Expected Result:**
- ✅ Multiple notes created (one per image)
- ✅ Each note has unique timestamp
- ✅ All images processed successfully

---

### 5. Quick Succession Shares

**Steps:**
1. Share a URL from Safari
2. Immediately (without opening Duru Notes)
3. Share text from Notes app
4. Then open Duru Notes app

**Expected Result:**
- ✅ Both shared items processed
- ✅ Two separate notes created
- ✅ No data loss
- ✅ Correct order (based on timestamps)

---

## Error Handling Tests

### 6. Cancel Share

**Steps:**
1. Open Safari, start sharing a URL
2. When Duru Notes share extension appears
3. Tap **Cancel** instead of **Post**

**Expected Result:**
- ✅ Extension dismisses cleanly
- ✅ No note created in Duru Notes
- ✅ No errors logged

---

### 7. Share with App Closed

**Steps:**
1. Force quit Duru Notes app (swipe up in app switcher)
2. Share content from Safari
3. Wait for extension to dismiss
4. Open Duru Notes app (cold start)

**Expected Result:**
- ✅ App launches normally
- ✅ ShareExtensionService processes shared items on launch
- ✅ Note created from shared content
- ✅ Shared items cleared from app group

---

### 8. Share with No Internet

**Steps:**
1. Enable Airplane Mode
2. Share content from Notes app
3. Open Duru Notes app

**Expected Result:**
- ✅ Note created locally
- ✅ Marked for sync when online
- ✅ No crash or error dialog

---

## Debugging Tips

### Check Console Logs

Use Xcode Console to see logs:

```
[ShareExtension] ✅ Successfully saved N items
[ShareExtension] ✅ Wrote N shared items to app group
[ShareExtension] ✅ Read N shared items from app group
[ShareExtension] ✅ Cleared shared items from app group
```

### Verify App Group Container

1. Attach to ShareExtension in Xcode
2. Set breakpoint in `ShareViewController.didSelectPost()`
3. Check `sharedItems` array contents
4. Verify JSON structure matches expected format

### Check Method Channel Communication

In Flutter app logs, look for:
```
[ShareExtensionService] Processing N shared items
[ShareExtensionService] Successfully processed shared [type]
```

---

## Performance Tests

### 9. Large Text Share

**Steps:**
1. Create a very long note (5000+ characters) in Notes app
2. Share to Duru Notes

**Expected Result:**
- ✅ Processes without timeout
- ✅ Full text captured
- ✅ Note created successfully

---

### 10. Large Image Share

**Steps:**
1. Share a high-resolution photo (10MB+)
2. Share to Duru Notes

**Expected Result:**
- ✅ Extension doesn't crash
- ✅ Image saved to shared container
- ✅ Main app processes image
- ✅ Uploaded to attachment service

---

## Success Criteria

All tests must pass:
- ✅ Text sharing works
- ✅ URL sharing works
- ✅ Image sharing works
- ✅ Multiple items handled correctly
- ✅ Quick succession shares work
- ✅ Cancel works cleanly
- ✅ Cold start processing works
- ✅ Offline mode works
- ✅ No memory leaks
- ✅ No crashes

---

## Known Limitations

Document any limitations found during testing:
- Share extension cannot access secure data (biometric lock)
- Images saved to shared container (temporary storage)
- Maximum 10 images per share action
- Extension has limited memory (120MB max)

---

## Completion

Once all tests pass:
- [ ] Update Master Implementation Plan
- [ ] Mark Quick Win #1 as complete
- [ ] Document any issues/workarounds
- [ ] Move to next phase
