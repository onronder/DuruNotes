const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://jtaedgpxesshdrnbgvjr.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI0NDk4MywiZXhwIjoyMDcwODIwOTgzfQ.KmGiBCovpxevvbBadsB5rwOgjiBFddhliPTWnrG3ASQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function verifyQuickCaptureSetup() {
  console.log('=== VERIFYING QUICK CAPTURE WIDGET SETUP ===\n');

  let successCount = 0;
  let totalChecks = 0;

  // 1. Check rate_limits table
  console.log('1. Checking rate_limits table:');
  totalChecks++;
  const { data: rateLimits, error: rateLimitsError } = await supabase
    .from('rate_limits')
    .select('*')
    .limit(1);
  
  if (!rateLimitsError) {
    console.log('   ✅ rate_limits table EXISTS');
    successCount++;
  } else {
    console.log('   ❌ rate_limits table NOT FOUND:', rateLimitsError.message);
  }

  // 2. Check analytics_events table
  console.log('\n2. Checking analytics_events table:');
  totalChecks++;
  const { data: analytics, error: analyticsError } = await supabase
    .from('analytics_events')
    .select('*')
    .limit(1);
  
  if (!analyticsError) {
    console.log('   ✅ analytics_events table EXISTS');
    successCount++;
  } else {
    console.log('   ❌ analytics_events table NOT FOUND:', analyticsError.message);
  }

  // 3. Check RPC function
  console.log('\n3. Checking rpc_get_quick_capture_summaries function:');
  totalChecks++;
  try {
    const { data, error } = await supabase.rpc('rpc_get_quick_capture_summaries', {
      p_limit: 1
    });
    
    if (!error) {
      console.log('   ✅ Function EXISTS and is callable');
      successCount++;
      if (data) {
        console.log(`   📊 Function returned ${data.length} results`);
      }
    } else {
      console.log('   ❌ Function error:', error.message);
    }
  } catch (e) {
    console.log('   ❌ Function NOT FOUND');
  }

  // 4. Test widget filtering
  console.log('\n4. Testing widget note filtering:');
  totalChecks++;
  const { data: widgetNotes, error: widgetError } = await supabase
    .from('notes')
    .select('id, title_enc, encrypted_metadata')
    .not('encrypted_metadata', 'is', null)
    .limit(5);
  
  if (!widgetError) {
    console.log('   ✅ Can query notes with metadata');
    successCount++;
    
    // Try to filter by widget source (even though we don't have any yet)
    const widgetCount = widgetNotes.filter(n => {
      try {
        const meta = JSON.parse(n.encrypted_metadata || '{}');
        return meta.source === 'widget';
      } catch {
        return false;
      }
    }).length;
    
    console.log(`   📊 Found ${widgetCount} widget notes`);
  } else {
    console.log('   ❌ Query error:', widgetError.message);
  }

  // 5. Check cleanup function
  console.log('\n5. Checking cleanup_old_rate_limits function:');
  totalChecks++;
  try {
    const { data, error } = await supabase.rpc('cleanup_old_rate_limits');
    
    if (!error) {
      console.log('   ✅ Cleanup function EXISTS');
      successCount++;
      if (data !== undefined) {
        console.log(`   📊 Cleanup returned: ${data} old entries removed`);
      }
    } else {
      console.log('   ❌ Function error:', error.message);
    }
  } catch (e) {
    console.log('   ❌ Function NOT FOUND');
  }

  // 6. Test creating a sample rate limit entry
  console.log('\n6. Testing rate limit functionality:');
  totalChecks++;
  const testKey = `test_widget_capture_${Date.now()}`;
  const { data: insertData, error: insertError } = await supabase
    .from('rate_limits')
    .insert({
      key: testKey,
      count: 1,
      window_start: new Date().toISOString()
    })
    .select()
    .single();
  
  if (!insertError) {
    console.log('   ✅ Can insert into rate_limits table');
    successCount++;
    
    // Clean up test entry
    await supabase
      .from('rate_limits')
      .delete()
      .eq('key', testKey);
  } else {
    console.log('   ❌ Insert error:', insertError.message);
  }

  // Summary
  console.log('\n' + '='.repeat(50));
  console.log(`SUMMARY: ${successCount}/${totalChecks} checks passed`);
  
  if (successCount === totalChecks) {
    console.log('✅ Quick Capture Widget backend is FULLY OPERATIONAL!');
    console.log('\nNext steps:');
    console.log('1. Deploy the Edge Function: ./deploy_quick_capture_function.sh');
    console.log('2. Proceed with iOS WidgetKit implementation (Phase 3)');
    console.log('3. Proceed with Android App Widget implementation (Phase 4)');
  } else {
    console.log('⚠️  Some components are missing or not working correctly');
    console.log('Please review the errors above and fix them before proceeding');
  }
}

verifyQuickCaptureSetup().then(() => {
  process.exit(0);
}).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
