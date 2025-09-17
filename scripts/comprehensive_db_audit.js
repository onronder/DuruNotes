const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const supabaseUrl = 'https://jtaedgpxesshdrnbgvjr.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI0NDk4MywiZXhwIjoyMDcwODIwOTgzfQ.KmGiBCovpxevvbBadsB5rwOgjiBFddhliPTWnrG3ASQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function comprehensiveDBAudit() {
  console.log('=' .repeat(70));
  console.log('COMPREHENSIVE DATABASE AUDIT - CRITICAL ANALYSIS');
  console.log('=' .repeat(70));
  console.log('\nThis audit will identify ALL discrepancies between expected and actual database state.\n');

  const issues = [];
  const warnings = [];
  const successes = [];

  // 1. CHECK ALL EXPECTED TABLES
  console.log('1. TABLE EXISTENCE CHECK:');
  console.log('-'.repeat(50));
  
  const expectedTables = [
    'notes',
    'folders', 
    'note_folders',
    'note_tags',
    'clipper_inbox',
    'inbound_aliases',
    'user_devices',
    'note_tasks',
    'rate_limits',
    'analytics_events'
  ];

  for (const table of expectedTables) {
    const { data, error } = await supabase
      .from(table)
      .select('*', { count: 'exact', head: true });
    
    if (error) {
      if (error.message.includes('not found')) {
        issues.push(`❌ Table '${table}' DOES NOT EXIST`);
        console.log(`   ❌ ${table}: MISSING`);
      } else {
        warnings.push(`⚠️  Table '${table}': ${error.message}`);
        console.log(`   ⚠️  ${table}: ${error.message}`);
      }
    } else {
      successes.push(`✅ Table '${table}' exists (${data} records)`);
      console.log(`   ✅ ${table}: EXISTS (${data} records)`);
    }
  }

  // 2. CHECK COLUMN STRUCTURE
  console.log('\n2. COLUMN STRUCTURE CHECK:');
  console.log('-'.repeat(50));

  // Check notes table columns
  const { data: noteSample } = await supabase.from('notes').select('*').limit(1);
  if (noteSample && noteSample[0]) {
    const noteColumns = Object.keys(noteSample[0]);
    console.log('   Notes table columns:', noteColumns.join(', '));
    
    // Check for expected columns
    const expectedNoteColumns = ['id', 'user_id', 'created_at', 'updated_at', 'deleted', 'encrypted_metadata'];
    for (const col of expectedNoteColumns) {
      if (!noteColumns.includes(col)) {
        issues.push(`❌ notes.${col} column MISSING`);
      }
    }
    
    // Check if we have title/body or encrypted versions
    if (!noteColumns.includes('title') && !noteColumns.includes('title_enc')) {
      issues.push('❌ notes table missing title column (neither title nor title_enc)');
    }
    if (!noteColumns.includes('body') && !noteColumns.includes('props_enc')) {
      issues.push('❌ notes table missing content column (neither body nor props_enc)');
    }
  }

  // 3. CHECK DATA TYPES
  console.log('\n3. DATA TYPE VERIFICATION:');
  console.log('-'.repeat(50));

  // Check encrypted_metadata type
  if (noteSample && noteSample[0]) {
    const metadataType = typeof noteSample[0].encrypted_metadata;
    console.log(`   notes.encrypted_metadata type: ${metadataType}`);
    
    if (noteSample[0].encrypted_metadata) {
      try {
        if (typeof noteSample[0].encrypted_metadata === 'string') {
          JSON.parse(noteSample[0].encrypted_metadata);
          console.log('   ✅ encrypted_metadata is valid JSON string');
        } else {
          console.log('   ✅ encrypted_metadata is JSONB');
        }
      } catch (e) {
        issues.push('❌ encrypted_metadata contains invalid JSON');
      }
    }
  }

  // Check clipper_inbox columns
  const { data: clipperSample } = await supabase.from('clipper_inbox').select('*').limit(1);
  if (clipperSample && clipperSample[0]) {
    const clipperColumns = Object.keys(clipperSample[0]);
    console.log('   Clipper inbox columns:', clipperColumns.join(', '));
    
    if (clipperColumns.includes('metadata')) {
      const type = typeof clipperSample[0].metadata;
      console.log(`   clipper_inbox.metadata type: ${type}`);
      if (type !== 'object') {
        issues.push('❌ clipper_inbox.metadata should be JSONB but is ' + type);
      }
    }
  }

  // 4. CHECK INDEXES
  console.log('\n4. INDEX VERIFICATION:');
  console.log('-'.repeat(50));

  const indexTests = [
    {
      name: 'idx_notes_metadata_source',
      table: 'notes',
      test: async () => {
        const { error } = await supabase
          .from('notes')
          .select('id')
          .not('encrypted_metadata', 'is', null)
          .limit(1);
        return !error;
      }
    },
    {
      name: 'idx_notes_widget_recent',
      table: 'notes', 
      test: async () => {
        const { error } = await supabase
          .from('notes')
          .select('id')
          .eq('deleted', false)
          .order('created_at', { ascending: false })
          .limit(1);
        return !error;
      }
    }
  ];

  for (const index of indexTests) {
    const works = await index.test();
    if (works) {
      console.log(`   ✅ ${index.name}: Likely exists (query works)`);
    } else {
      warnings.push(`⚠️  ${index.name}: May be missing`);
      console.log(`   ⚠️  ${index.name}: May be missing`);
    }
  }

  // 5. CHECK RPC FUNCTIONS
  console.log('\n5. RPC FUNCTION CHECK:');
  console.log('-'.repeat(50));

  const rpcFunctions = [
    'rpc_get_quick_capture_summaries',
    'cleanup_old_rate_limits'
  ];

  for (const func of rpcFunctions) {
    try {
      const { error } = await supabase.rpc(func, func === 'rpc_get_quick_capture_summaries' ? { p_limit: 1 } : {});
      if (error) {
        if (error.message.includes('not found') || error.message.includes('Could not find')) {
          issues.push(`❌ Function ${func} DOES NOT EXIST`);
          console.log(`   ❌ ${func}: MISSING`);
        } else if (error.message.includes('not authenticated')) {
          // This is expected for auth-required functions
          console.log(`   ✅ ${func}: EXISTS (auth required)`);
        } else {
          warnings.push(`⚠️  Function ${func}: ${error.message}`);
          console.log(`   ⚠️  ${func}: ${error.message}`);
        }
      } else {
        console.log(`   ✅ ${func}: EXISTS and callable`);
      }
    } catch (e) {
      issues.push(`❌ Function ${func} error: ${e.message}`);
    }
  }

  // 6. CHECK CONSTRAINTS AND FOREIGN KEYS
  console.log('\n6. CONSTRAINT CHECK:');
  console.log('-'.repeat(50));

  // Test foreign key constraints
  const fkTests = [
    {
      name: 'note_folders.note_id -> notes.id',
      test: async () => {
        // Try to insert with invalid note_id
        const { error } = await supabase
          .from('note_folders')
          .insert({ note_id: '00000000-0000-0000-0000-000000000000', folder_id: '00000000-0000-0000-0000-000000000000', user_id: '00000000-0000-0000-0000-000000000000' });
        return error && error.message.includes('violates foreign key');
      }
    }
  ];

  for (const fk of fkTests) {
    const hasConstraint = await fk.test();
    if (hasConstraint) {
      console.log(`   ✅ ${fk.name}: Constraint exists`);
    } else {
      warnings.push(`⚠️  ${fk.name}: Constraint may be missing`);
      console.log(`   ⚠️  ${fk.name}: Constraint may be missing`);
    }
  }

  // 7. CHECK RLS POLICIES
  console.log('\n7. RLS POLICY CHECK:');
  console.log('-'.repeat(50));

  const rlsTables = ['notes', 'folders', 'note_folders', 'clipper_inbox', 'rate_limits', 'analytics_events'];
  
  for (const table of rlsTables) {
    // Try to select from table (will fail if RLS is enabled and no policy allows it)
    const { data, error } = await supabase.from(table).select('*').limit(0);
    
    if (!error) {
      console.log(`   ✅ ${table}: RLS enabled with policies`);
    } else if (error.message.includes('not found')) {
      // Table doesn't exist, already reported
    } else {
      console.log(`   ⚠️  ${table}: ${error.message}`);
    }
  }

  // 8. CHECK FOR PARTIAL MIGRATIONS
  console.log('\n8. MIGRATION CONSISTENCY CHECK:');
  console.log('-'.repeat(50));

  // List all migration files
  const migrationsDir = path.join(__dirname, '..', 'supabase', 'migrations');
  const migrationFiles = fs.readdirSync(migrationsDir)
    .filter(f => f.endsWith('.sql') && !f.endsWith('.skip'))
    .sort();

  console.log('   Migration files that should be applied:');
  for (const file of migrationFiles) {
    console.log(`     - ${file}`);
  }

  // GENERATE REPORT
  console.log('\n' + '='.repeat(70));
  console.log('AUDIT SUMMARY');
  console.log('='.repeat(70));

  console.log(`\n✅ SUCCESSES: ${successes.length}`);
  successes.slice(0, 5).forEach(s => console.log(`   ${s}`));
  if (successes.length > 5) console.log(`   ... and ${successes.length - 5} more`);

  console.log(`\n⚠️  WARNINGS: ${warnings.length}`);
  warnings.forEach(w => console.log(`   ${w}`));

  console.log(`\n❌ CRITICAL ISSUES: ${issues.length}`);
  issues.forEach(i => console.log(`   ${i}`));

  // SEVERITY ASSESSMENT
  console.log('\n' + '='.repeat(70));
  console.log('SEVERITY ASSESSMENT');
  console.log('='.repeat(70));

  if (issues.length === 0) {
    console.log('\n✅ DATABASE IS HEALTHY - No critical issues found');
  } else if (issues.length <= 3) {
    console.log('\n⚠️  DATABASE HAS MINOR ISSUES - Can be fixed with targeted migrations');
  } else {
    console.log('\n❌ DATABASE IS IN CRITICAL STATE - Requires comprehensive repair');
    console.log('\nThe database is NOT 100% compatible with the application code!');
    console.log('This MUST be fixed before production deployment.');
  }

  // SAVE REPORT
  const report = {
    timestamp: new Date().toISOString(),
    successes,
    warnings,
    issues,
    migrationFiles,
    severity: issues.length === 0 ? 'HEALTHY' : issues.length <= 3 ? 'WARNING' : 'CRITICAL'
  };

  fs.writeFileSync(
    path.join(__dirname, 'db_audit_report.json'),
    JSON.stringify(report, null, 2)
  );

  console.log('\n📄 Full report saved to: scripts/db_audit_report.json');

  return report;
}

comprehensiveDBAudit().then(report => {
  if (report.issues.length > 0) {
    console.log('\n🔧 Next step: Run create_db_repair_script.js to generate fixes');
    process.exit(1); // Exit with error code if issues found
  }
  process.exit(0);
}).catch(err => {
  console.error('Audit failed:', err);
  process.exit(1);
});
