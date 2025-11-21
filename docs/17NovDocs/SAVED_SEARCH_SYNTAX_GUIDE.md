# Saved Search Syntax Guide
**Feature**: Phase 2.1 - Advanced Search Query Syntax
**Status**: ✅ Production Ready
**Date**: November 21, 2025

---

## Overview

Duru Notes supports an advanced search syntax that allows you to create powerful, reusable searches using filters and text queries. This guide explains all available syntax options and provides real-world examples.

---

## Basic Concepts

### Plain Text Search
The simplest form of search - just type your search terms:

```
meeting notes
```

This searches across:
- Note titles
- Note body content
- Note tags

### Quoted Text
Use quotes for exact phrase matching:

```
"project status update"
```

---

## Filter Syntax

Filters use the format `key:value` to narrow down search results.

### Available Filters

#### 1. Folder Filter
**Syntax**: `folder:FolderName`
**Purpose**: Limit results to notes in a specific folder

**Examples**:
```
folder:Work
folder:Personal
folder:Projects
```

**Use Case**: Find all notes in your "Work" folder
```
folder:Work
```

---

#### 2. Tag Filters
**Syntax**: `tag:TagName`
**Purpose**: Find notes with specific tags
**Logic**: Multiple tags use AND logic (note must have ALL specified tags)

**Examples**:
```
tag:urgent
tag:urgent tag:important
tag:meeting tag:q4
```

**Use Cases**:

Find urgent items:
```
tag:urgent
```

Find items that are both urgent AND important:
```
tag:urgent tag:important
```

Find Q4 meeting notes:
```
tag:meeting tag:q4
```

---

#### 3. Attachment Filter
**Syntax**: `has:attachment` or `has:attachments`
**Purpose**: Find notes with file attachments

**Examples**:
```
has:attachment
has:attachments
```

**Use Case**: Find all notes with attached files
```
has:attachment
```

---

#### 4. Reminder Filter
**Syntax**: `has:reminder` or `has:reminders`
**Purpose**: Find notes with reminders set

**Examples**:
```
has:reminder
has:reminders
```

**Use Case**: Find notes that have reminders
```
has:reminder
```

---

#### 5. Status Filter
**Syntax**: `status:StatusName`
**Purpose**: Filter by note status

**Examples**:
```
status:active
status:completed
status:archived
```

**Use Case**: Find completed tasks
```
status:completed
```

---

#### 6. Type Filter
**Syntax**: `type:TypeName`
**Purpose**: Filter by note type

**Examples**:
```
type:note
type:task
type:checklist
```

**Use Case**: Find all task-type notes
```
type:task
```

---

#### 7. Date Range Filters

##### After Date
**Syntax**: `after:YYYY-MM-DD`
**Purpose**: Find notes created after a specific date

**Examples**:
```
after:2025-01-01
after:2025-11-15
```

**Use Case**: Find notes created in 2025
```
after:2025-01-01
```

##### Before Date
**Syntax**: `before:YYYY-MM-DD`
**Purpose**: Find notes created before a specific date

**Examples**:
```
before:2025-12-31
before:2025-06-30
```

**Use Case**: Find notes from first half of 2025
```
after:2025-01-01 before:2025-06-30
```

---

## Combining Filters and Text

You can combine multiple filters and text searches to create powerful queries:

### Syntax
```
filter1:value1 filter2:value2 "quoted text" plain text
```

### Examples

#### Work meetings with urgent tag:
```
folder:Work tag:urgent meeting
```

#### Recent important tasks:
```
type:task tag:important after:2025-11-01
```

#### Q4 project notes with attachments:
```
folder:Projects tag:q4 has:attachment
```

#### Completed tasks in personal folder:
```
folder:Personal status:completed type:task
```

---

## Real-World Examples

### 1. Weekly Review Search
Find all notes from the past week with the "review" tag:

```
tag:review after:2025-11-14
```

### 2. Client Meeting Preparation
Find all meeting notes for a specific client with attachments:

```
folder:Clients tag:meeting has:attachment "Acme Corp"
```

### 3. Urgent Action Items
Find urgent tasks that are not yet completed:

```
type:task tag:urgent status:active
```

### 4. Project Documentation
Find all project documentation with specific tags:

```
folder:Projects tag:documentation tag:published
```

### 5. Annual Review
Find all notes from 2024:

```
after:2024-01-01 before:2024-12-31
```

### 6. Personal Reminders
Find personal notes with reminders set:

```
folder:Personal has:reminder status:active
```

### 7. Archive Search
Find completed items with attachments from Q3:

```
status:completed has:attachment after:2025-07-01 before:2025-09-30
```

### 8. Multi-Tag Research
Find research notes tagged with multiple topics:

```
tag:research tag:ai tag:productivity "large language models"
```

---

## Advanced Tips

### 1. Autocomplete Suggestions
Start typing a filter keyword to see autocomplete suggestions:
- Type `fol` → suggests `folder:`
- Type `tag` → suggests `tag:`
- Type `has` → suggests `has:attachment`, `has:reminder`
- Type `status` → suggests `status:active`, `status:completed`

### 2. Query Validation
The system validates your query syntax in real-time:
- ✅ Valid date formats: `YYYY-MM-DD`
- ✅ Valid filter keys: folder, tag, has, status, type, before, after
- ❌ Invalid dates will show an error
- ❌ Unknown filter values for `has:` will show an error

### 3. Case Sensitivity
- Filter keys are case-insensitive: `folder:Work` = `FOLDER:work`
- Filter values are case-sensitive: `folder:Work` ≠ `folder:work`
- Text search is case-insensitive: `meeting` finds "Meeting" and "MEETING"

### 4. Special Characters
- Use quotes to include special characters in search terms
- Colons in regular text (like `3:00 PM`) are treated as text, not filters
- Valid filter format: `validkey:value` (no spaces around colon)

### 5. Empty Filters
- Empty filter values are allowed but may not be useful
- Example: `folder:` matches notes with empty folder field

---

## Query Syntax Reference

### Complete Syntax
```
[folder:FolderName] [tag:Tag1] [tag:Tag2] ...
[has:attachment|reminder] [status:StatusName] [type:TypeName]
[before:YYYY-MM-DD] [after:YYYY-MM-DD]
["quoted text"] [plain text terms]
```

### Valid Filter Keys
| Filter | Description | Example |
|--------|-------------|---------|
| `folder:` | Filter by folder | `folder:Work` |
| `tag:` | Filter by tag (repeatable) | `tag:urgent tag:important` |
| `has:` | Has attachment/reminder | `has:attachment` `has:reminder` |
| `status:` | Filter by status | `status:completed` |
| `type:` | Filter by note type | `type:task` |
| `before:` | Before date (YYYY-MM-DD) | `before:2025-12-31` |
| `after:` | After date (YYYY-MM-DD) | `after:2025-01-01` |

### Valid `has:` Values
- `attachment` or `attachments`
- `reminder` or `reminders`

---

## Troubleshooting

### Common Errors

#### Error: "Invalid date format"
**Cause**: Date is not in YYYY-MM-DD format
**Fix**: Use format like `2025-11-21` instead of `11/21/2025`

```
❌ before:11/21/2025
✅ before:2025-11-21
```

#### Error: "Unknown 'has' filter value"
**Cause**: Invalid value after `has:`
**Fix**: Use `attachment`, `attachments`, `reminder`, or `reminders`

```
❌ has:files
✅ has:attachment
```

#### Error: "Invalid query syntax"
**Cause**: Query has validation errors
**Fix**: Check for invalid dates or unknown filter values

---

## Performance Notes

- **Efficient**: Filters are applied at the database level for speed
- **Smart Caching**: Results are cached for faster subsequent searches
- **Real-time**: Updates reflect immediately as you type
- **Scalable**: Works efficiently with thousands of notes

---

## Feature Comparison

### Simple Search vs. Advanced Search

| Feature | Simple Search | Advanced Search |
|---------|--------------|-----------------|
| Text search | ✅ | ✅ |
| Folder filtering | ❌ | ✅ |
| Tag filtering | ❌ | ✅ |
| Date range | ❌ | ✅ |
| Attachments | ❌ | ✅ |
| Reminders | ❌ | ✅ |
| Status/Type | ❌ | ✅ |
| Multiple filters | ❌ | ✅ |
| Save searches | ❌ | ✅ |
| Reusable | ❌ | ✅ |

---

## Next Steps

1. **Try It Out**: Create your first saved search using the syntax above
2. **Pin Favorites**: Pin frequently-used searches for quick access
3. **Organize**: Use descriptive names for your saved searches
4. **Iterate**: Refine queries based on results
5. **Share**: Document useful queries for team members

---

## Related Documentation

- **Repository Layer**: `lib/infrastructure/repositories/saved_search_core_repository.dart`
- **Service Layer**: `lib/services/search/saved_search_service.dart`
- **Query Parser**: `lib/services/search/saved_search_query_parser.dart`
- **Progress Report**: `MasterImplementation Phases/TRACK_2_PHASE_2.1_PROGRESS.md`

---

**Document Status**: ✅ Complete
**Last Updated**: November 21, 2025
**Phase**: Track 2, Phase 2.1 (Organization Features)
**Test Coverage**: 77/77 tests passing
