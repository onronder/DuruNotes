# Testing Guide: Rich Text Formatting Toolbar (E2.2)

## Overview
This test guide verifies that the formatting toolbar works correctly in the Modern Note Editor.

## Test Cases

### 1. Toolbar Visibility
- [ ] Open the note editor (tap + button)
- [ ] Initially, toolbar should NOT be visible
- [ ] Tap on the body field - toolbar should slide down with animation
- [ ] Tap on the title field - toolbar should slide up and disappear
- [ ] Return to body field - toolbar should reappear

### 2. Text Formatting Buttons
Test each button with and without text selection:

#### Bold Button (B icon)
- [ ] Type "test" and select it
- [ ] Tap Bold button
- [ ] Text should become `**test**`
- [ ] Place cursor in empty area
- [ ] Tap Bold button
- [ ] Should insert `****` with cursor between asterisks

#### Italic Button (I icon)
- [ ] Type "test" and select it
- [ ] Tap Italic button
- [ ] Text should become `*test*`
- [ ] Place cursor in empty area
- [ ] Tap Italic button
- [ ] Should insert `**` with cursor between asterisks

#### Heading Button (T icon)
- [ ] Place cursor at start of line
- [ ] Tap Heading button
- [ ] Should insert `## ` at cursor position
- [ ] Type heading text after it

### 3. List Formatting Buttons

#### Bullet List (• icon)
- [ ] Place cursor on new line
- [ ] Tap Bullet list button
- [ ] Should insert `• ` at start of line
- [ ] Type list item text

#### Numbered List (1. icon)
- [ ] Place cursor on new line
- [ ] Tap Numbered list button
- [ ] Should insert `1. ` at start of line
- [ ] Type list item text

#### Checkbox List (☑ icon)
- [ ] Place cursor on new line
- [ ] Tap Checkbox button
- [ ] Should insert `- [ ] ` at start of line
- [ ] Type task text

### 4. Advanced Formatting

#### Code Button (</> icon)
- [ ] Type "code" and select it
- [ ] Tap Code button
- [ ] Text should become `` `code` ``
- [ ] Empty selection: should insert `` `` `` with cursor between

#### Quote Button (" icon)
- [ ] Place cursor on new line
- [ ] Tap Quote button
- [ ] Should insert `> ` at start of line
- [ ] Type quote text

#### Link Button (🔗 icon)
- [ ] Type "link text" and select it
- [ ] Tap Link button
- [ ] Text should become `[link text](url)`
- [ ] Empty selection: should insert `[](url)`

#### Image Button (🖼 icon)
- [ ] Place cursor in empty area
- [ ] Tap Image button
- [ ] Should insert `![alt]()`
- [ ] Can fill in alt text and URL

### 5. UI/UX Checks

#### Scrollability
- [ ] On small screen, toolbar should be horizontally scrollable
- [ ] All buttons should be accessible via scrolling

#### Visual Feedback
- [ ] Each button tap should trigger haptic feedback
- [ ] Tooltips should appear on long press
- [ ] Button press should show ink ripple effect

#### Theming
- [ ] Toolbar should adapt to light/dark mode
- [ ] Icons should be visible in both themes
- [ ] Background should be translucent surfaceVariant

### 6. Edge Cases

- [ ] Formatting at start of document
- [ ] Formatting at end of document
- [ ] Multiple formatting on same text (bold + italic)
- [ ] Toolbar remains visible while typing
- [ ] Cursor position is correct after each insertion

## Expected Behavior Summary

1. **Toolbar appears ONLY when body field is focused**
2. **Smooth slide animation (300ms) for show/hide**
3. **All formatting buttons insert correct Markdown syntax**
4. **Haptic feedback on each button press**
5. **Toolbar groups are separated by dividers**
6. **Maintains focus on body field after formatting**
7. **Cursor positioned correctly after each insertion**

## Notes
- The toolbar should not interfere with typing
- Keyboard should remain visible when using toolbar
- All Markdown syntax should be valid and renderable
