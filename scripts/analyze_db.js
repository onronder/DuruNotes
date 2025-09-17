const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://jtaedgpxesshdrnbgvjr.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI0NDk4MywiZXhwIjoyMDcwODIwOTgzfQ.KmGiBCovpxevvbBadsB5rwOgjiBFddhliPTWnrG3ASQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function analyzeDatabase() {
  console.log('=== DATABASE ANALYSIS ===\n');

  try {
    // Check migration history
    console.log('1. MIGRATION HISTORY:');
    const { data: migrations, error: migError } = await supabase.rpc('get_migration_history');
    if (migError) {
      // Try direct query
      const { data, error } = await supabase
        .from('schema_migrations')
        .select('*')
        .order('version', { ascending: false });
      
      if (error) {
        console.log('Cannot access migration history:', error.message);
      } else {
        console.log('Applied migrations:', data);
      }
    } else {
      console.log('Applied migrations:', migrations);
    }

    // Check tables
    console.log('\n2. EXISTING TABLES:');
    const tables = ['notes', 'folders', 'note_folders', 'clipper_inbox', 'inbound_aliases', 'user_devices', 'note_tasks'];
    for (const table of tables) {
      const { count, error } = await supabase
        .from(table)
        .select('*', { count: 'exact', head: true });
      
      if (error) {
        console.log(`   ${table}: NOT FOUND or ERROR - ${error.message}`);
      } else {
        console.log(`   ${table}: EXISTS (${count} records)`);
      }
    }

    // Check for specific columns
    console.log('\n3. CHECKING METADATA COLUMNS:');
    const { data: notesSample, error: notesError } = await supabase
      .from('notes')
      .select('id, encrypted_metadata')
      .limit(1);
    
    if (!notesError && notesSample && notesSample.length > 0) {
      console.log('   notes.encrypted_metadata: EXISTS');
      console.log('   Type check:', typeof notesSample[0].encrypted_metadata);
    }

    const { data: clipperSample, error: clipperError } = await supabase
      .from('clipper_inbox')
      .select('id, metadata, payload_json')
      .limit(1);
    
    if (!clipperError && clipperSample) {
      console.log('   clipper_inbox.metadata: EXISTS');
      console.log('   clipper_inbox.payload_json: EXISTS');
      if (clipperSample.length > 0) {
        console.log('   metadata type:', typeof clipperSample[0].metadata);
        console.log('   payload_json type:', typeof clipperSample[0].payload_json);
      }
    }

    // Check for RPC functions
    console.log('\n4. CHECKING RPC FUNCTIONS:');
    try {
      const { data, error } = await supabase.rpc('rpc_get_quick_capture_summaries', {
        p_limit: 1
      });
      
      if (error) {
        console.log('   rpc_get_quick_capture_summaries: NOT FOUND -', error.message);
      } else {
        console.log('   rpc_get_quick_capture_summaries: EXISTS');
      }
    } catch (e) {
      console.log('   rpc_get_quick_capture_summaries: NOT FOUND');
    }

    // Check indexes (we'll need to use raw SQL for this)
    console.log('\n5. CHECKING INDEXES:');
    const indexQuery = `
      SELECT indexname, indexdef
      FROM pg_indexes
      WHERE schemaname = 'public'
      AND tablename = 'notes'
      AND indexname LIKE '%metadata%'
    `;
    
    // We can't run raw SQL directly, but we can check if our queries work
    const { data: widgetNotes, error: widgetError } = await supabase
      .from('notes')
      .select('id, title')
      .eq('encrypted_metadata->source', 'widget')
      .limit(5);
    
    if (!widgetError) {
      console.log('   Widget source filtering: WORKS');
      console.log('   Found widget notes:', widgetNotes?.length || 0);
    } else {
      console.log('   Widget source filtering: ERROR -', widgetError.message);
    }

    // Check RLS policies by trying operations
    console.log('\n6. CHECKING RLS POLICIES:');
    
    // This will fail if policies don't exist or are misconfigured
    const { data: testSelect, error: selectError } = await supabase
      .from('notes')
      .select('id')
      .limit(1);
    
    console.log('   notes SELECT policy:', selectError ? `ERROR - ${selectError.message}` : 'WORKS');

    const { data: testClipperSelect, error: clipperSelectError } = await supabase
      .from('clipper_inbox')
      .select('id')
      .limit(1);
    
    console.log('   clipper_inbox SELECT policy:', clipperSelectError ? `ERROR - ${clipperSelectError.message}` : 'WORKS');

  } catch (error) {
    console.error('Analysis error:', error);
  }
}

analyzeDatabase().then(() => {
  console.log('\n=== ANALYSIS COMPLETE ===');
  process.exit(0);
});
