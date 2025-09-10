# Saved Searches – QA Checklist

## Setup

Before testing, ensure the following test data exists:

1. **Email-in note** (tag `#Email`)
   - Create via email-in or manually add `#Email` tag
   - Should have metadata source = "email_in"

2. **Web Clip note** (tag `#Web`)
   - Create via web clipper or manually add `#Web` tag
   - Should have metadata source = "web"

3. **Attachment note** (has at least one file/image; tag `#Attachment`)
   - Upload any file/image to a note
   - Should have `#Attachment` tag

4. **Inbox item** (Incoming Mail folder)
   - Ensure at least one email or web clip exists in the inbox
   - Check the "Incoming Mail" folder has content

## Chips Testing

### Visual Presence
- [ ] SavedSearchChips appear below search bar when not searching
- [ ] Four chips visible: Attachments, Email Notes, Web Clips, Inbox
- [ ] Icons match: 📎 Attachments, 📧 Email Notes, 🌐 Web Clips, 📥 Inbox

### Chip Navigation
- [ ] **Tap Attachments** → Only notes with attachments listed
- [ ] **Tap Email Notes** → Only email-origin notes listed
- [ ] **Tap Web Clips** → Only web-origin notes listed
- [ ] **Tap Inbox** → Main list switches to "Incoming Mail" folder (same state as folder chips)

## Search Tokens Testing

### Basic Token Searches
- [ ] Type `has:attachment` → Same result set as Attachments chip
- [ ] Type `from:email` → Same result set as Email Notes chip
- [ ] Type `from:web` → Same result set as Web Clips chip
- [ ] Type `folder:"Incoming Mail"` → Only notes in that folder
- [ ] Type `folder:Inbox` → Same as above (mapped to Incoming Mail)

### Combined Token Searches
- [ ] Type `from:email budget` → Only email-origin notes with "budget" in title/body
- [ ] Type `from:web design` → Only web-origin notes with "design" in title/body
- [ ] Type `folder:"Incoming Mail" attachment` → Only inbox notes containing "attachment"
- [ ] Type `folder:Inbox from:email` → Only email notes in the inbox

### Case Insensitivity
- [ ] `HAS:ATTACHMENT` works same as `has:attachment`
- [ ] `FROM:EMAIL` works same as `from:email`
- [ ] `FOLDER:INBOX` works same as `folder:inbox`

## Edge Cases

### Empty States
- [ ] Search with no results shows "No results found" with search icon
- [ ] Empty folder shows appropriate empty state
- [ ] Chips with zero items optionally hide (if hideZeroCount enabled)

### Mixed Tokens
- [ ] `from:web has:attachment` → Only web notes that also have attachments
- [ ] `from:email folder:"Incoming Mail"` → Only email notes in inbox
- [ ] `has:attachment from:email budget` → Email notes with attachments containing "budget"

### UI State Consistency
- [ ] Switching between saved search chips maintains correct highlighting
- [ ] Switching between folder chips and saved search chips updates correctly
- [ ] Search bar clears when switching between chips
- [ ] No stale highlights when navigating back from search

### Token Parsing
- [ ] Quoted folder names work: `folder:"My Folder"`
- [ ] Unquoted folder names work: `folder:MyFolder`
- [ ] Tokens are stripped from keyword search (e.g., `from:email test` searches for "test")
- [ ] Multiple spaces handled correctly

## Performance

- [ ] Search results appear quickly (< 1 second)
- [ ] Folder filtering shows loading indicator when needed
- [ ] No UI freezes or jank during search
- [ ] Large result sets paginate properly

## Pass Criteria

All assertions must hold:
- [ ] After app restart
- [ ] After a full sync cycle
- [ ] With both empty and populated folders
- [ ] On both iOS and Android platforms

## Additional Verification

### Data Integrity
- [ ] Tags persist correctly (#Email, #Web, #Attachment)
- [ ] Metadata source field correctly identifies origin
- [ ] Folder assignments remain stable

### Navigation Flow
- [ ] Back button from search returns to correct state
- [ ] Deep linking to searches works (if implemented)
- [ ] Keyboard dismisses appropriately

### Accessibility
- [ ] Chips are accessible via screen reader
- [ ] Search tokens announced correctly
- [ ] Empty states have appropriate descriptions

## Known Limitations

1. Folder filtering requires async lookup (shows loading state)
2. Tag-based fallback used when metadata unavailable
3. "Inbox" maps to "Incoming Mail" for convenience

## Test Data Creation Scripts

### Create Email Note
```dart
// Via ClipperInboxService
// Tags: ['Email', 'Attachment'] if has attachments
// Metadata: source = 'email_in'
```

### Create Web Clip
```dart
// Via ClipperInboxService
// Tags: ['Web']
// Metadata: source = 'web'
```

### Create Note with Attachment
```dart
// Via UI or API
// Tags: ['Attachment']
// Metadata: attachments field populated
```

## Regression Tests

- [ ] Existing search functionality still works
- [ ] Folder navigation unchanged
- [ ] Tag filtering unaffected
- [ ] Note creation/editing works normally

---

**Last Updated**: December 2024
**Feature Version**: 1.0.0
**Test Coverage**: Manual + Unit Tests
