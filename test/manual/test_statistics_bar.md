# Testing Guide: Note Statistics Bar (E2.5)

## Overview
This test guide verifies that the note statistics bar displays accurate real-time information about the note content and save status.

## Test Cases

### 1. Initial Display

#### Empty Note
- [ ] Create a new note (tap + button)
- [ ] Statistics bar should show at bottom
- [ ] Verify initial values:
  - 0 words
  - 0 chars
  - 0 min
  - "Saved" status (green/primary color)

#### Existing Note
- [ ] Open an existing note with content
- [ ] Statistics should immediately reflect current content
- [ ] Status should show "Saved" if no changes made

### 2. Real-time Updates

#### Word Count
- [ ] Type "Hello world" in body
- [ ] Should show "2 words"
- [ ] Add "test" → should update to "3 words"
- [ ] Delete "test" → should return to "2 words"
- [ ] Clear all text → should return to "0 words"

#### Character Count
- [ ] Type "Hello" (5 characters)
- [ ] Should show "5 chars"
- [ ] Add a space → "6 chars"
- [ ] Add "world" → "11 chars"
- [ ] Includes spaces, newlines, all characters

#### Multiple Words
- [ ] Type a sentence with 10 words
- [ ] Verify word count updates correctly
- [ ] Add multiple spaces between words
- [ ] Word count should remain same (regex handles whitespace)

### 3. Reading Time Calculation

#### Under 200 Words
- [ ] Type content with 1-199 words
- [ ] Should show "1 min" reading time
- [ ] At exactly 200 words, still "1 min"

#### Over 200 Words
- [ ] Type content with 201 words
- [ ] Should show "2 min"
- [ ] 400 words → "2 min"
- [ ] 401 words → "3 min"
- [ ] Formula: ceil(words/200)

#### Edge Cases
- [ ] 0 words → "0 min"
- [ ] 1 word → "1 min"
- [ ] 1000 words → "5 min"

### 4. Save Status Indicator

#### Unsaved State
- [ ] Type any character in title or body
- [ ] Status should immediately change to:
  - "Unsaved" text
  - Red error color
  - Edit note icon
  - Reddish background tint

#### Saved State
- [ ] Tap Save button
- [ ] After successful save, status shows:
  - "Saved" text
  - Primary/blue color
  - Cloud done icon
  - Blue/green background tint

#### Animation
- [ ] Status change should animate smoothly (300ms)
- [ ] Background color fades between states

### 5. Visual Design

#### Chip Styling
- [ ] Each stat chip should have:
  - Rounded corners (8px radius)
  - Subtle surfaceVariant background (30% opacity)
  - Appropriate icon
  - Value in bold (font weight 600)
  - Label in smaller, lighter text

#### Layout
- [ ] Stats bar at bottom of screen
- [ ] Subtle top shadow for separation
- [ ] Horizontal spacing between chips (12px)
- [ ] Padding around entire bar

#### Scrollability
- [ ] On very small screens or large text
- [ ] Row should be horizontally scrollable
- [ ] All chips remain accessible

### 6. Theme Compatibility

#### Light Mode
- [ ] All text clearly visible
- [ ] Chips have subtle gray backgrounds
- [ ] Save status colors appropriate

#### Dark Mode
- [ ] Switch to dark theme
- [ ] Text contrasts properly
- [ ] Chips darker but still visible
- [ ] Save status colors adapted

### 7. Integration with Other Features

#### With Formatting
- [ ] Apply bold/italic formatting
- [ ] Stats should update if text added
- [ ] Save status changes to "Unsaved"

#### With Preview Mode
- [ ] Switch to preview mode
- [ ] Stats bar remains visible
- [ ] Shows current statistics
- [ ] Save status unchanged

#### With Save Operation
- [ ] Make changes → "Unsaved" appears
- [ ] Save note → "Saved" appears
- [ ] If save fails, remains "Unsaved"

### 8. Performance

#### Typing Speed
- [ ] Type continuously at normal speed
- [ ] Stats should update smoothly
- [ ] No lag or stuttering
- [ ] UI remains responsive

#### Large Documents
- [ ] Paste 1000+ word document
- [ ] Stats should calculate quickly
- [ ] No performance degradation
- [ ] Smooth scrolling maintained

### 9. Edge Cases

#### Special Characters
- [ ] Type emojis 🚀💡⭐
- [ ] Character count includes them
- [ ] Word count handles properly

#### Markdown Syntax
- [ ] Type **bold** and *italic*
- [ ] Characters include markdown symbols
- [ ] Word count treats as regular text

#### Whitespace
- [ ] Multiple spaces: "word    word"
- [ ] Should count as 2 words (regex collapses spaces)
- [ ] Multiple newlines handled correctly

#### Very Long Single Word
- [ ] Type 100-character word without spaces
- [ ] Should count as 1 word
- [ ] Character count accurate

### 10. Accessibility

#### Text Scaling
- [ ] Increase system font size
- [ ] Stats text should remain readable
- [ ] May trigger horizontal scroll if needed

#### Touch Targets
- [ ] Stats chips are display-only
- [ ] Should not respond to taps
- [ ] No confusing interactions

## Expected Behavior Summary

1. **Real-time Updates**: Stats update immediately on every keystroke
2. **Accurate Counts**: Word and character counts are precise
3. **Reading Time**: Based on 200 words/minute standard
4. **Save Status**: Clear visual indication of saved/unsaved state
5. **Smooth Animations**: 300ms transitions for status changes
6. **Theme Aware**: Adapts to light/dark modes
7. **Performance**: No lag even with large documents
8. **Always Visible**: Stats bar present in both edit and preview modes

## Test Data Examples

### Short Note
```
Title: Quick Note
Body: This is a test.
Expected: 4 words, 15 chars, 1 min
```

### Medium Note (250 words)
```
[Paste 250-word lorem ipsum]
Expected: 250 words, ~1500 chars, 2 min
```

### Long Note (1000 words)
```
[Paste 1000-word article]
Expected: 1000 words, ~6000 chars, 5 min
```

## Visual Verification

- Stats bar doesn't overlap content
- Smooth transitions between states
- Consistent spacing and alignment
- Professional, unobtrusive appearance
