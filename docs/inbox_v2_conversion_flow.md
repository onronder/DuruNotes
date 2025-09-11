# Inbox V2 Conversion Flow

## Single Source of Truth
All inbox item conversions (email and web clips) flow through **`InboxManagementService.convertInboxItemToNote()`**

## Conversion Process

### Email Items (`source_type: 'email_in'`)
1. **Title**: Subject or "Email from {sender}"
2. **Body Format**:
   ```
   {email content}
   
   ---
   From: {sender}
   Received: {ISO 8601 timestamp}
   
   #Email [#Attachment if has attachments]
   ```
3. **Metadata**:
   - `source: 'email_in'`
   - `from`, `to`, `received_at`
   - `message_id`, `original_id`
   - `attachments` (if present)
   - `html` (if present)
   - `tags: ['Email', 'Attachment']` (as applicable)

### Web Clips (`source_type: 'web'`)
1. **Title**: Page title or "Web Clip"
2. **Body Format**:
   ```
   {clipped text}
   
   ---
   Source: {URL}
   Clipped: {ISO 8601 timestamp}
   
   #Web
   ```
3. **Metadata**:
   - `source: 'web'`
   - `url`, `clipped_at`
   - `original_id`
   - `html` (if present)
   - `tags: ['Web']`

## Post-Conversion Actions
1. Note is added to **"Incoming Mail"** folder via `IncomingMailFolderManager`
2. Original `clipper_inbox` row is deleted (user-scoped)
3. Note ID is returned for confirmation

## Disabled Auto-Processing
- `ClipperInboxService._handleEmailRow()` - DEPRECATED (only runs if `kInboxAutoProcess = true`)
- `ClipperInboxService._handleWebRow()` - DEPRECATED (only runs if `kInboxAutoProcess = true`)
- Default: `kInboxAutoProcess = false` (items stay in inbox until manual conversion)

## Tags
- **In Body**: Added as hashtags at the end of the note
- **In Metadata**: Stored without `#` prefix in `tags` array
- Email items: `#Email`, `#Attachment` (if has attachments)
- Web clips: `#Web`

## Security
- All operations are user-scoped with `.eq('user_id', userId)`
- Deletion only occurs after successful note creation
- Folder assignment failures don't block conversion
