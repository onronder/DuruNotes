# Phase 4: Folder Management CRUD Implementation Guide

## Overview

This document provides a comprehensive guide for implementing and using the production-grade folder management system introduced in Phase 4 of Duru Notes.

## Database Schema Enhancements

### Folders Table Structure

The `folders` table has been enhanced with the following columns:

```sql
CREATE TABLE public.folders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    name_enc BYTEA NOT NULL,        -- Encrypted folder name
    props_enc BYTEA NOT NULL,       -- Encrypted folder properties
    parent_id UUID REFERENCES public.folders(id) ON DELETE CASCADE,
    sort_order INTEGER DEFAULT 0,   -- Display order within parent
    path TEXT,                      -- Materialized path for efficient queries
    depth INTEGER DEFAULT 0,        -- Hierarchy depth (0-10 levels)
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ DEFAULT now(),
    deleted BOOLEAN DEFAULT false
);
```

### Key Features

1. **Hierarchical Structure**: Support for nested folders up to 10 levels deep
2. **Materialized Path**: Efficient hierarchy queries using path column
3. **Sort Order**: Custom ordering within each hierarchy level
4. **Soft Delete**: Non-destructive deletion with recovery capability
5. **Conflict Detection**: Optimistic locking with updated_at timestamps

## CRUD Functions

### 1. Create Folder

```sql
SELECT create_folder(
    p_user_id := auth.uid(),
    p_name_enc := 'encrypted_folder_name'::bytea,
    p_props_enc := '{"color": "blue", "icon": "folder"}'::bytea,
    p_parent_id := NULL,  -- Root folder
    p_sort_order := 0
);
```

**Features:**
- Validates user permissions
- Enforces maximum depth constraints
- Automatically calculates hierarchy information
- Returns the new folder ID

### 2. Update Folder

```sql
SELECT update_folder(
    p_folder_id := 'folder-uuid',
    p_user_id := auth.uid(),
    p_name_enc := 'new_encrypted_name'::bytea,
    p_props_enc := '{"color": "red"}'::bytea,
    p_sort_order := 5,
    p_expected_updated_at := '2025-09-24 10:30:00'::timestamptz
);
```

**Features:**
- Conflict detection with expected timestamp
- Partial updates (NULL values ignored)
- Returns new updated_at timestamp
- Validates user access

### 3. Move Folder

```sql
SELECT move_folder(
    p_folder_id := 'folder-uuid',
    p_user_id := auth.uid(),
    p_new_parent_id := 'parent-folder-uuid',
    p_new_sort_order := 3
);
```

**Features:**
- Prevents circular references
- Validates depth constraints
- Updates entire subtree hierarchy
- Maintains data integrity

### 4. Delete Folder

```sql
SELECT delete_folder(
    p_folder_id := 'folder-uuid',
    p_user_id := auth.uid(),
    p_cascade_notes := true,     -- Remove notes from folder
    p_force_delete := false      -- Delete even with children
);
```

**Features:**
- Safe deletion with validation
- Optional note cascading
- Force delete for non-empty folders
- Soft delete implementation

### 5. Get Folder Tree

```sql
SELECT * FROM get_folder_tree(
    p_user_id := auth.uid(),
    p_parent_id := NULL,         -- Root folders
    p_max_depth := 10
);
```

**Returns:**
- Complete folder hierarchy
- Child and note counts
- Optimized for UI rendering
- Efficient recursive queries

## Performance Optimizations

### Indexes

The migration creates several optimized indexes:

1. **Hierarchy Index**: `(user_id, parent_id, sort_order, id)`
2. **Path Index**: `(user_id, path)` for materialized path queries
3. **Depth Index**: `(user_id, depth, sort_order)` for level-based queries
4. **Timestamp Index**: `(user_id, updated_at DESC)` for recent changes

### Query Patterns

**Find all subfolders:**
```sql
SELECT * FROM folders
WHERE user_id = auth.uid()
AND path LIKE 'parent-id/%'
AND deleted = false;
```

**Get folder breadcrumb:**
```sql
WITH path_parts AS (
    SELECT unnest(string_to_array(path, '/'))::uuid as folder_id
    FROM folders WHERE id = 'target-folder-id'
)
SELECT f.* FROM folders f
JOIN path_parts pp ON f.id = pp.folder_id
ORDER BY f.depth;
```

## Security Features

### Row Level Security (RLS)

Comprehensive RLS policies ensure:
- Users can only access their own folders
- All operations (SELECT, INSERT, UPDATE, DELETE) are protected
- Future-ready for shared folder features

### Function Security

All functions use `SECURITY DEFINER` with:
- User validation on every operation
- Permission checking before data access
- Protection against privilege escalation

## Real-time Subscriptions

### Configuration

The migration enables real-time subscriptions for:
- `public.folders` table changes
- `public.note_folders` relationship changes

### Subscription Examples

**Listen to folder changes:**
```javascript
const subscription = supabase
  .channel('folder_changes')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'folders',
    filter: `user_id=eq.${userId}`
  }, (payload) => {
    console.log('Folder changed:', payload);
  })
  .subscribe();
```

**Listen to note-folder relationships:**
```javascript
const subscription = supabase
  .channel('note_folder_changes')
  .on('postgres_changes', {
    event: '*',
    schema: 'public',
    table: 'note_folders',
    filter: `user_id=eq.${userId}`
  }, (payload) => {
    console.log('Note-folder relationship changed:', payload);
  })
  .subscribe();
```

## Migration Verification

### Post-Migration Checks

Run these queries after migration:

1. **Verify table structure:**
```sql
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'folders'
ORDER BY ordinal_position;
```

2. **Verify indexes:**
```sql
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public' AND tablename IN ('folders', 'note_folders')
ORDER BY tablename, indexname;
```

3. **Verify functions:**
```sql
SELECT routine_name, routine_type
FROM information_schema.routines
WHERE routine_schema = 'public' AND routine_name LIKE '%folder%'
ORDER BY routine_name;
```

4. **Test folder creation:**
```sql
SELECT create_folder(
    auth.uid()::uuid,
    'Test Folder'::bytea,
    '{"color": "blue"}'::bytea,
    NULL,
    0
);
```

## Error Handling

### Common Error Scenarios

1. **Circular Reference**: Moving folder into its own subtree
2. **Maximum Depth**: Exceeding 10-level hierarchy limit
3. **Access Denied**: User trying to access other user's folders
4. **Conflict Detection**: Concurrent modification detection
5. **Missing Parent**: Referencing non-existent parent folder

### Error Messages

The system provides clear, actionable error messages:
- `Access denied: insufficient permissions`
- `Maximum folder depth (10 levels) would be exceeded`
- `Cannot move folder: would create circular reference`
- `Conflict detected: folder was modified by another process`

## Rollback Procedures

### Emergency Rollback

If issues arise, use the rollback function:

```sql
SELECT rollback_phase4_folder_management();
```

**Warning**: This removes all Phase 4 enhancements but preserves data.

### Manual Rollback Steps

For partial rollback:

1. **Drop specific functions:**
```sql
DROP FUNCTION IF EXISTS create_folder(UUID, BYTEA, BYTEA, UUID, INTEGER);
```

2. **Disable triggers:**
```sql
DROP TRIGGER IF EXISTS folders_hierarchy_update_trigger ON public.folders;
```

3. **Remove indexes:**
```sql
DROP INDEX IF EXISTS idx_folders_user_hierarchy;
```

## Best Practices

### Application Integration

1. **Batch Operations**: Use transactions for multiple folder operations
2. **Conflict Resolution**: Implement retry logic for conflicts
3. **Caching Strategy**: Cache folder trees with invalidation on changes
4. **Error Handling**: Provide user-friendly error messages

### Performance Considerations

1. **Lazy Loading**: Load folder trees incrementally
2. **Pagination**: Limit folder tree depth in UI
3. **Index Usage**: Ensure queries use the optimized indexes
4. **Connection Pooling**: Use connection pooling for high-concurrency scenarios

### Security Guidelines

1. **Input Validation**: Validate all encrypted data before storage
2. **Rate Limiting**: Implement rate limiting for folder operations
3. **Audit Logging**: Log all folder operations for compliance
4. **Access Control**: Regularly review folder access patterns

## Monitoring and Maintenance

### Key Metrics

Monitor these metrics for optimal performance:

1. **Query Performance**: Average response time for folder operations
2. **Hierarchy Depth**: Distribution of folder depths
3. **Operation Frequency**: CRUD operation rates
4. **Conflict Rate**: Frequency of optimistic locking conflicts

### Maintenance Tasks

1. **Index Maintenance**: Regular REINDEX for optimal performance
2. **Statistics Update**: Keep table statistics current
3. **Cleanup**: Periodic cleanup of soft-deleted folders
4. **Backup Verification**: Test folder hierarchy restoration

## Future Enhancements

The current implementation provides a foundation for:

1. **Shared Folders**: Multi-user folder access with permissions
2. **Folder Templates**: Pre-configured folder structures
3. **Bulk Operations**: Efficient batch folder operations
4. **Search Integration**: Full-text search within folder hierarchies
5. **Audit Trail**: Complete operation history tracking

## Support and Troubleshooting

### Common Issues

1. **Slow Hierarchy Queries**: Check index usage and update statistics
2. **Lock Contention**: Review concurrent operation patterns
3. **Memory Usage**: Monitor recursive query performance
4. **Real-time Delays**: Check subscription filter efficiency

### Debugging Tools

1. **Query Plans**: Use EXPLAIN ANALYZE for performance analysis
2. **Lock Monitoring**: Monitor pg_locks for contention
3. **Index Usage**: Check pg_stat_user_indexes for efficiency
4. **Function Performance**: Monitor function execution times

For additional support, refer to the Supabase documentation and PostgreSQL best practices guides.