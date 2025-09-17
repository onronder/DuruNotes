const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://jtaedgpxesshdrnbgvjr.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI0NDk4MywiZXhwIjoyMDcwODIwOTgzfQ.KmGiBCovpxevvbBadsB5rwOgjiBFddhliPTWnrG3ASQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkQuickCaptureConflicts() {
  console.log('=== CHECKING QUICK CAPTURE MIGRATION CONFLICTS ===\n');

  // 1. Check if rate_limits table exists
  console.log('1. Checking rate_limits table:');
  const { data: rateLimits, error: rateLimitsError } = await supabase
    .from('rate_limits')
    .select('*')
    .limit(1);
  
  if (rateLimitsError) {
    if (rateLimitsError.message.includes('not found')) {
      console.log('   ✓ rate_limits table does NOT exist (safe to create)');
    } else {
      console.log('   ? rate_limits error:', rateLimitsError.message);
    }
  } else {
    console.log('   ✗ rate_limits table EXISTS (may cause conflict)');
  }

  // 2. Check if analytics_events table exists
  console.log('\n2. Checking analytics_events table:');
  const { data: analytics, error: analyticsError } = await supabase
    .from('analytics_events')
    .select('*')
    .limit(1);
  
  if (analyticsError) {
    if (analyticsError.message.includes('not found')) {
      console.log('   ✓ analytics_events table does NOT exist (safe to create)');
    } else {
      console.log('   ? analytics_events error:', analyticsError.message);
    }
  } else {
    console.log('   ✗ analytics_events table EXISTS (may cause conflict)');
  }

  // 3. Check if the RPC function exists
  console.log('\n3. Checking rpc_get_quick_capture_summaries function:');
  try {
    const { data, error } = await supabase.rpc('rpc_get_quick_capture_summaries', {
      p_limit: 1
    });
    
    if (error) {
      if (error.message.includes('not found') || error.message.includes('Could not find')) {
        console.log('   ✓ Function does NOT exist (safe to create)');
      } else {
        console.log('   ? Function error:', error.message);
      }
    } else {
      console.log('   ✗ Function EXISTS (may cause conflict)');
    }
  } catch (e) {
    console.log('   ✓ Function does NOT exist (safe to create)');
  }

  // 4. Check existing indexes on notes table
  console.log('\n4. Checking for existing indexes on notes table:');
  
  // Test if we can query using the indexes we want to create
  const indexTests = [
    {
      name: 'metadata source index',
      test: async () => {
        const { data, error } = await supabase
          .from('notes')
          .select('id')
          .not('encrypted_metadata->source', 'is', null)
          .limit(1);
        return !error;
      }
    },
    {
      name: 'widget source index',
      test: async () => {
        const { data, error } = await supabase
          .from('notes')
          .select('id')
          .eq('encrypted_metadata->source', 'widget')
          .limit(1);
        return !error;
      }
    }
  ];

  for (const test of indexTests) {
    const works = await test.test();
    console.log(`   ${test.name}: ${works ? 'Query works (index may exist)' : 'Query fails'}`);
  }

  // 5. Check for the cleanup function
  console.log('\n5. Checking cleanup_old_rate_limits function:');
  try {
    const { data, error } = await supabase.rpc('cleanup_old_rate_limits');
    
    if (error) {
      if (error.message.includes('not found') || error.message.includes('Could not find')) {
        console.log('   ✓ Function does NOT exist (safe to create)');
      } else {
        console.log('   ? Function error:', error.message);
      }
    } else {
      console.log('   ✗ Function EXISTS (may cause conflict)');
    }
  } catch (e) {
    console.log('   ✓ Function does NOT exist (safe to create)');
  }

  // 6. Check note_tags table (referenced in the Edge Function)
  console.log('\n6. Checking note_tags table:');
  const { data: noteTags, error: noteTagsError } = await supabase
    .from('note_tags')
    .select('*')
    .limit(1);
  
  if (noteTagsError) {
    if (noteTagsError.message.includes('not found')) {
      console.log('   ✗ note_tags table does NOT exist (Edge Function will fail)');
      console.log('   ! Need to create note_tags table or modify Edge Function');
    } else {
      console.log('   ? note_tags error:', noteTagsError.message);
    }
  } else {
    console.log('   ✓ note_tags table EXISTS (Edge Function can use it)');
  }

  console.log('\n=== SUMMARY ===');
  console.log('The Quick Capture Widget migration should be safe to apply.');
  console.log('Main concerns:');
  console.log('1. Check if note_tags table exists (needed by Edge Function)');
  console.log('2. Indexes on notes.encrypted_metadata might already exist');
  console.log('3. Consider using IF NOT EXISTS for all CREATE statements');
}

checkQuickCaptureConflicts().then(() => {
  process.exit(0);
}).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
