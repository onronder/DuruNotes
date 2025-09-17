const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://jtaedgpxesshdrnbgvjr.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI0NDk4MywiZXhwIjoyMDcwODIwOTgzfQ.KmGiBCovpxevvbBadsB5rwOgjiBFddhliPTWnrG3ASQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function findMigrationsTable() {
  console.log('=== FINDING MIGRATIONS TABLE ===\n');

  // Check if we can access the migrations through Supabase CLI's expected location
  console.log('Checking standard Supabase migration locations...\n');
    
    // Try different schemas
    const schemas = ['public', 'supabase_migrations'];
    
    for (const schema of schemas) {
      console.log(`Checking schema: ${schema}`);
      
      // Try with different client configurations
      const client = createClient(supabaseUrl, supabaseKey, {
        db: { schema: schema },
        auth: { persistSession: false }
      });
      
      try {
        const { data: tables, error } = await client
          .from('schema_migrations')
          .select('version')
          .limit(1);
        
        if (!error) {
          console.log(`  ✓ Found schema_migrations in ${schema}`);
          
          // Get all migrations
          const { data: migrations, error: migError } = await client
            .from('schema_migrations')
            .select('*')
            .order('version', { ascending: false });
          
          if (!migError && migrations) {
            console.log('\nApplied migrations:');
            migrations.forEach(m => {
              console.log(`  ${m.version}: Applied at ${m.executed_at || 'unknown time'}`);
            });
          }
          return { schema, migrations };
        } else {
          console.log(`  ✗ Not in ${schema}: ${error.message}`);
        }
      } catch (e) {
        console.log(`  ✗ Error checking ${schema}: ${e.message}`);
      }
    }
  
  // Also check what the actual error is when we try to apply migrations
  console.log('\n=== CHECKING SPECIFIC MIGRATION CONFLICTS ===\n');
  
  // Check for existing policies that might conflict
  const policyChecks = [
    { table: 'clipper_inbox', policy: 'users_select_own_inbox' },
    { table: 'inbound_aliases', policy: 'users_select_own_alias' },
    { table: 'notes', policy: 'users_select_own_notes' },
    { table: 'folders', policy: 'users_select_own_folders' },
    { table: 'note_folders', policy: 'users_select_own_note_folders' },
    { table: 'user_devices', policy: 'users_select_own_devices' },
    { table: 'note_tasks', policy: 'users_select_own_tasks' }
  ];
  
  console.log('Checking for existing RLS policies that might conflict:');
  
  // We can't directly query pg_policies through Supabase client, but we can check if tables work
  for (const check of policyChecks) {
    const { data, error } = await supabase
      .from(check.table)
      .select('id')
      .limit(0); // Just check if we can access
    
    if (!error) {
      console.log(`  ${check.table}: Accessible (policies exist)`);
    } else {
      console.log(`  ${check.table}: ${error.message}`);
    }
  }
  
  // Check for indexes that might conflict
  console.log('\n=== CHECKING FOR CONFLICTING INDEXES ===\n');
  
  // Try to use the notes table with metadata filtering
  const { data: metadataTest, error: metadataError } = await supabase
    .from('notes')
    .select('id')
    .not('encrypted_metadata', 'is', null)
    .limit(1);
  
  if (!metadataError) {
    console.log('Notes metadata column exists and is queryable');
  } else {
    console.log('Notes metadata error:', metadataError.message);
  }
  
  // Check clipper_inbox structure
  const { data: clipperTest, error: clipperError } = await supabase
    .from('clipper_inbox')
    .select('id, metadata, payload_json')
    .limit(1);
  
  if (!clipperError) {
    console.log('Clipper inbox has metadata and payload_json columns');
    if (clipperTest && clipperTest[0]) {
      console.log('  metadata type:', typeof clipperTest[0].metadata);
      console.log('  payload_json type:', typeof clipperTest[0].payload_json);
    }
  }
}

findMigrationsTable().then(() => {
  console.log('\n=== ANALYSIS COMPLETE ===');
  process.exit(0);
}).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
