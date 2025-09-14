/**
 * RLS (Row-Level Security) Policy Tests
 * 
 * This test suite verifies that unauthorized users cannot access or modify
 * data in restricted tables. It tests both anonymous and cross-user access.
 */

import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { describe, it, expect, beforeAll, afterAll } from '@jest/globals';

// Test configuration
const SUPABASE_URL = process.env.SUPABASE_URL || 'http://localhost:54321';
const SUPABASE_ANON_KEY = process.env.SUPABASE_ANON_KEY || '';
const SUPABASE_SERVICE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY || '';

// Test user credentials
const TEST_USER_1 = {
  email: 'test-user-1@example.com',
  password: 'TestPassword123!',
  id: ''
};

const TEST_USER_2 = {
  email: 'test-user-2@example.com',
  password: 'TestPassword456!',
  id: ''
};

describe('RLS Policy Tests', () => {
  let anonClient: SupabaseClient;
  let serviceClient: SupabaseClient;
  let user1Client: SupabaseClient;
  let user2Client: SupabaseClient;

  beforeAll(async () => {
    // Initialize clients
    anonClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    serviceClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);

    // Create test users using service role
    const { data: user1, error: error1 } = await serviceClient.auth.admin.createUser({
      email: TEST_USER_1.email,
      password: TEST_USER_1.password,
      email_confirm: true
    });
    
    if (error1) throw new Error(`Failed to create user 1: ${error1.message}`);
    TEST_USER_1.id = user1.user.id;

    const { data: user2, error: error2 } = await serviceClient.auth.admin.createUser({
      email: TEST_USER_2.email,
      password: TEST_USER_2.password,
      email_confirm: true
    });
    
    if (error2) throw new Error(`Failed to create user 2: ${error2.message}`);
    TEST_USER_2.id = user2.user.id;

    // Create authenticated clients for each user
    user1Client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    await user1Client.auth.signInWithPassword({
      email: TEST_USER_1.email,
      password: TEST_USER_1.password
    });

    user2Client = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);
    await user2Client.auth.signInWithPassword({
      email: TEST_USER_2.email,
      password: TEST_USER_2.password
    });

    // Insert test data for user 1
    await setupTestData();
  });

  afterAll(async () => {
    // Clean up test users
    await serviceClient.auth.admin.deleteUser(TEST_USER_1.id);
    await serviceClient.auth.admin.deleteUser(TEST_USER_2.id);
  });

  async function setupTestData() {
    // Insert test data using service role to bypass RLS
    
    // Insert test note
    await serviceClient
      .from('notes')
      .insert({
        id: 'test-note-1',
        user_id: TEST_USER_1.id,
        title_enc: Buffer.from('Test Note').toString('base64'),
        content_enc: Buffer.from('Test Content').toString('base64')
      });

    // Insert test inbox item
    await serviceClient
      .from('clipper_inbox')
      .insert({
        id: 'test-inbox-1',
        user_id: TEST_USER_1.id,
        source_type: 'web',
        title: 'Test Clip',
        content: 'Test content',
        metadata: { url: 'https://example.com' }
      });

    // Insert test alias
    await serviceClient
      .from('inbound_aliases')
      .insert({
        user_id: TEST_USER_1.id,
        alias: 'test_alias_user1'
      });

    // Insert test folder if table exists
    const { error: folderError } = await serviceClient
      .from('folders')
      .insert({
        id: 'test-folder-1',
        user_id: TEST_USER_1.id,
        name_enc: Buffer.from('Test Folder').toString('base64'),
        props_enc: Buffer.from('{}').toString('base64')
      });

    if (!folderError) {
      // Insert note-folder mapping
      await serviceClient
        .from('note_folders')
        .insert({
          note_id: 'test-note-1',
          folder_id: 'test-folder-1',
          user_id: TEST_USER_1.id
        });
    }

    // Insert test task if table exists
    await serviceClient
      .from('note_tasks')
      .insert({
        id: 'test-task-1',
        user_id: TEST_USER_1.id,
        note_id: 'test-note-1',
        content: 'Test Task',
        content_hash: 'hash123',
        status: 0
      });
  }

  describe('Anonymous Access Tests', () => {
    it('should block anonymous SELECT on clipper_inbox', async () => {
      const { data, error } = await anonClient
        .from('clipper_inbox')
        .select('*');
      
      expect(data).toEqual([]);
      // Anonymous users get empty results, not errors
    });

    it('should block anonymous INSERT on clipper_inbox', async () => {
      const { error } = await anonClient
        .from('clipper_inbox')
        .insert({
          user_id: TEST_USER_1.id,
          source_type: 'web',
          title: 'Unauthorized',
          content: 'Should fail'
        });
      
      expect(error).toBeTruthy();
      expect(error?.message).toContain('new row violates row-level security');
    });

    it('should block anonymous UPDATE on clipper_inbox', async () => {
      const { error } = await anonClient
        .from('clipper_inbox')
        .update({ title: 'Hacked' })
        .eq('id', 'test-inbox-1');
      
      expect(error).toBeTruthy();
      // Update on non-visible rows returns error or affects 0 rows
    });

    it('should block anonymous DELETE on clipper_inbox', async () => {
      const { error } = await anonClient
        .from('clipper_inbox')
        .delete()
        .eq('id', 'test-inbox-1');
      
      expect(error).toBeTruthy();
      // Delete on non-visible rows returns error or affects 0 rows
    });

    it('should block anonymous access to inbound_aliases', async () => {
      const { data } = await anonClient
        .from('inbound_aliases')
        .select('*');
      
      expect(data).toEqual([]);
    });

    it('should block anonymous access to notes', async () => {
      const { data } = await anonClient
        .from('notes')
        .select('*');
      
      expect(data).toEqual([]);
    });
  });

  describe('Cross-User Access Tests', () => {
    it('should block user2 from reading user1 clipper_inbox', async () => {
      const { data } = await user2Client
        .from('clipper_inbox')
        .select('*')
        .eq('user_id', TEST_USER_1.id);
      
      expect(data).toEqual([]);
    });

    it('should block user2 from updating user1 clipper_inbox', async () => {
      const { data, error } = await user2Client
        .from('clipper_inbox')
        .update({ title: 'Hacked by user2' })
        .eq('id', 'test-inbox-1');
      
      // Should affect 0 rows since user2 can't see user1's data
      expect(data).toEqual([]);
    });

    it('should block user2 from deleting user1 clipper_inbox', async () => {
      const { data } = await user2Client
        .from('clipper_inbox')
        .delete()
        .eq('id', 'test-inbox-1');
      
      // Should affect 0 rows
      expect(data).toEqual([]);
      
      // Verify item still exists (using service client)
      const { data: checkData } = await serviceClient
        .from('clipper_inbox')
        .select('id')
        .eq('id', 'test-inbox-1')
        .single();
      
      expect(checkData).toBeTruthy();
    });

    it('should block user2 from reading user1 inbound_aliases', async () => {
      const { data } = await user2Client
        .from('inbound_aliases')
        .select('*')
        .eq('user_id', TEST_USER_1.id);
      
      expect(data).toEqual([]);
    });

    it('should block user2 from reading user1 notes', async () => {
      const { data } = await user2Client
        .from('notes')
        .select('*')
        .eq('user_id', TEST_USER_1.id);
      
      expect(data).toEqual([]);
    });

    it('should block user2 from inserting notes for user1', async () => {
      const { error } = await user2Client
        .from('notes')
        .insert({
          id: 'malicious-note',
          user_id: TEST_USER_1.id, // Trying to insert as user1
          title_enc: Buffer.from('Malicious').toString('base64'),
          content_enc: Buffer.from('Hacked').toString('base64')
        });
      
      expect(error).toBeTruthy();
      expect(error?.message).toContain('new row violates row-level security');
    });
  });

  describe('Legitimate User Access Tests', () => {
    it('should allow user1 to read their own clipper_inbox', async () => {
      const { data, error } = await user1Client
        .from('clipper_inbox')
        .select('*')
        .eq('id', 'test-inbox-1');
      
      expect(error).toBeFalsy();
      expect(data).toHaveLength(1);
      expect(data?.[0].id).toBe('test-inbox-1');
    });

    it('should allow user1 to update their own clipper_inbox', async () => {
      const { data, error } = await user1Client
        .from('clipper_inbox')
        .update({ 
          converted_to_note_id: 'test-note-1',
          converted_at: new Date().toISOString()
        })
        .eq('id', 'test-inbox-1')
        .select();
      
      expect(error).toBeFalsy();
      expect(data).toHaveLength(1);
      expect(data?.[0].converted_to_note_id).toBe('test-note-1');
    });

    it('should allow user1 to delete their own clipper_inbox', async () => {
      // Create a new item to delete
      await serviceClient
        .from('clipper_inbox')
        .insert({
          id: 'test-inbox-to-delete',
          user_id: TEST_USER_1.id,
          source_type: 'web',
          title: 'To Delete',
          content: 'Will be deleted'
        });

      const { error } = await user1Client
        .from('clipper_inbox')
        .delete()
        .eq('id', 'test-inbox-to-delete');
      
      expect(error).toBeFalsy();
      
      // Verify deletion
      const { data: checkData } = await user1Client
        .from('clipper_inbox')
        .select('id')
        .eq('id', 'test-inbox-to-delete');
      
      expect(checkData).toEqual([]);
    });

    it('should allow user1 to read their own alias', async () => {
      const { data, error } = await user1Client
        .from('inbound_aliases')
        .select('*')
        .single();
      
      expect(error).toBeFalsy();
      expect(data?.alias).toBe('test_alias_user1');
    });

    it('should allow user1 to read their own notes', async () => {
      const { data, error } = await user1Client
        .from('notes')
        .select('*')
        .eq('id', 'test-note-1');
      
      expect(error).toBeFalsy();
      expect(data).toHaveLength(1);
    });

    it('should allow user1 to create new notes', async () => {
      const { data, error } = await user1Client
        .from('notes')
        .insert({
          id: 'new-note-by-user1',
          user_id: TEST_USER_1.id,
          title_enc: Buffer.from('New Note').toString('base64'),
          content_enc: Buffer.from('New Content').toString('base64')
        })
        .select();
      
      expect(error).toBeFalsy();
      expect(data).toHaveLength(1);
    });
  });

  describe('Storage RLS Tests', () => {
    it('should block anonymous access to attachments', async () => {
      const { data, error } = await anonClient
        .storage
        .from('attachments')
        .list(TEST_USER_1.id);
      
      expect(error).toBeTruthy();
      // Anonymous users should not be able to list attachments
    });

    it('should block user2 from accessing user1 attachments', async () => {
      // First, upload a test file as user1
      const testFile = new Blob(['test content'], { type: 'text/plain' });
      await user1Client
        .storage
        .from('attachments')
        .upload(`${TEST_USER_1.id}/test.txt`, testFile);

      // Try to access as user2
      const { data, error } = await user2Client
        .storage
        .from('attachments')
        .download(`${TEST_USER_1.id}/test.txt`);
      
      expect(error).toBeTruthy();
      // User2 should not be able to download user1's files
    });

    it('should allow user1 to access their own attachments', async () => {
      const { data, error } = await user1Client
        .storage
        .from('attachments')
        .list(TEST_USER_1.id);
      
      expect(error).toBeFalsy();
      // User1 should be able to list their own attachments
    });
  });
});

// Export test runner
export async function runRLSTests() {
  console.log('Running RLS Policy Tests...');
  console.log('================================');
  
  try {
    // Run tests
    await import('jest').then((jest) => {
      jest.run();
    });
  } catch (error) {
    console.error('Test execution failed:', error);
    process.exit(1);
  }
}

// Run tests if executed directly
if (require.main === module) {
  runRLSTests();
}
