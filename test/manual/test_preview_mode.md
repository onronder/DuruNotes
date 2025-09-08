# Testing Guide: Markdown Preview Mode (E2.3)

## Overview
This test guide verifies that the Markdown preview mode works correctly in the Modern Note Editor.

## Test Cases

### 1. Toggle Control
- [ ] Open the note editor (tap + button)
- [ ] Verify preview toggle button appears in header (right side)
- [ ] Button should show preview icon when in edit mode
- [ ] Tap preview button - should switch to preview mode with animation
- [ ] Button should now show edit icon and have highlighted background
- [ ] Tap again to return to edit mode
- [ ] Verify haptic feedback occurs on toggle

### 2. UI Transitions
- [ ] Toggle between modes - verify smooth 300ms fade transition
- [ ] No jarring jumps or flashes during transition
- [ ] Content should remain consistent between modes

### 3. Preview Content Display

#### Title Display
- [ ] Enter a title in edit mode
- [ ] Switch to preview - title should appear as large header
- [ ] Title should have separator line below it
- [ ] If no title, preview should not show empty space

#### Markdown Rendering
Test each Markdown element:

##### Text Formatting
- [ ] **Bold text** using `**text**` renders as bold
- [ ] *Italic text* using `*text*` renders as italic
- [ ] ***Bold italic*** using `***text***` renders correctly
- [ ] Inline `code` using backticks renders with background

##### Headings
- [ ] `# Heading 1` renders as large heading
- [ ] `## Heading 2` renders as medium heading
- [ ] `### Heading 3` renders as smaller heading

##### Lists
- [ ] Bullet lists with `• ` render properly
- [ ] Numbered lists with `1. ` render with numbers
- [ ] Task lists `- [ ]` and `- [x]` render as checkboxes

##### Advanced Elements
- [ ] Blockquotes with `> ` render as italicized, indented text
- [ ] Links `[text](url)` render as clickable links
- [ ] Images `![alt](url)` show image placeholder or actual image
- [ ] Code blocks with triple backticks render with background

### 4. Preview Interactions

#### Content Selection
- [ ] Text in preview can be selected
- [ ] Selected text can be copied
- [ ] Links are tappable (if valid URLs)

#### Read-Only Behavior
- [ ] Cannot edit text in preview mode
- [ ] Keyboard does not appear when tapping preview
- [ ] No cursor appears in preview

### 5. Toolbar Behavior
- [ ] Formatting toolbar is hidden in preview mode
- [ ] Even if body was focused before, toolbar stays hidden
- [ ] Returning to edit mode doesn't auto-show toolbar
- [ ] Must focus body field again to show toolbar

### 6. State Preservation
- [ ] Make edits in edit mode
- [ ] Switch to preview - changes appear immediately
- [ ] Switch back to edit - all text is preserved
- [ ] Cursor position may reset (acceptable)
- [ ] Unsaved changes indicator still works

### 7. Empty State
- [ ] With no body content, preview shows "*No content to preview*"
- [ ] Message appears in italics
- [ ] Still shows title if present

### 8. Theme Compatibility

#### Light Mode
- [ ] All text is readable
- [ ] Code blocks have subtle background
- [ ] Links are visible with primary color
- [ ] Blockquotes are distinguishable

#### Dark Mode
- [ ] Switch to dark theme
- [ ] All text contrasts properly
- [ ] Code blocks don't have glaring backgrounds
- [ ] Separator lines are visible but subtle

### 9. Performance
- [ ] Large documents (1000+ words) render smoothly
- [ ] No lag when toggling modes
- [ ] Scrolling in preview is smooth

### 10. Complex Markdown Test

Create a note with this content and verify it renders correctly:

```markdown
# My Test Note

This is a paragraph with **bold**, *italic*, and `inline code`.

## Lists

### Bullet List
• First item
• Second item
• Third item

### Numbered List
1. First step
2. Second step
3. Third step

### Task List
- [x] Completed task
- [ ] Pending task

## Formatting

> This is a blockquote
> spanning multiple lines

Here's a [link](https://example.com) and an image:
![Test Image](https://via.placeholder.com/150)

```code block
function test() {
  return "Hello";
}
```
```

## Expected Behavior Summary

1. **Toggle button changes icon based on mode**
2. **Smooth 300ms transition between modes**
3. **All Markdown elements render correctly**
4. **Preview is read-only and selectable**
5. **Formatting toolbar hidden in preview**
6. **State preserved when switching modes**
7. **Theme colors applied consistently**
8. **No performance issues with large content**

## Edge Cases to Test

- Toggle rapidly between modes - should handle gracefully
- Preview with only whitespace
- Preview with invalid Markdown syntax
- Very long single lines
- Deeply nested lists
- Mixed Markdown elements
