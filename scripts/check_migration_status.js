const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const supabaseUrl = 'https://jtaedgpxesshdrnbgvjr.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI0NDk4MywiZXhwIjoyMDcwODIwOTgzfQ.KmGiBCovpxevvbBadsB5rwOgjiBFddhliPTWnrG3ASQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkMigrationStatus() {
  console.log('=' .repeat(70));
  console.log('MIGRATION STATUS ANALYSIS');
  console.log('=' .repeat(70));

  // Get list of local migration files
  const migrationsDir = path.join(__dirname, '..', 'supabase', 'migrations');
  const allFiles = fs.readdirSync(migrationsDir).sort();
  
  const activeFiles = allFiles.filter(f => f.endsWith('.sql'));
  const skippedFiles = allFiles.filter(f => f.endsWith('.skip'));

  console.log('\n📁 LOCAL MIGRATION FILES:');
  console.log('-'.repeat(50));
  
  console.log('\nACTIVE MIGRATIONS:');
  activeFiles.forEach(f => {
    const version = f.split('_')[0];
    console.log(`  ✓ ${version}: ${f}`);
  });

  console.log('\nSKIPPED MIGRATIONS:');
  skippedFiles.forEach(f => {
    const version = f.replace('.skip', '').split('_')[0];
    console.log(`  ⊘ ${version}: ${f}`);
  });

  // Now check what each migration is supposed to do and verify it's applied
  console.log('\n' + '='.repeat(70));
  console.log('MIGRATION VERIFICATION');
  console.log('=' .repeat(70));

  const verificationResults = [];

  // Check specific migrations we know about
  const migrationChecks = [
    {
      file: '20250120_quick_capture_widget.sql',
      checks: [
        {
          name: 'rate_limits table',
          test: async () => {
            const { error } = await supabase.from('rate_limits').select('*').limit(1);
            return !error;
          }
        },
        {
          name: 'analytics_events table',
          test: async () => {
            const { error } = await supabase.from('analytics_events').select('*').limit(1);
            return !error;
          }
        },
        {
          name: 'rpc_get_quick_capture_summaries function',
          test: async () => {
            const { error } = await supabase.rpc('rpc_get_quick_capture_summaries', { p_limit: 1 });
            return !error || error.message.includes('authenticated');
          }
        }
      ]
    },
    {
      file: '20250119_note_tasks.sql',
      checks: [
        {
          name: 'note_tasks table',
          test: async () => {
            const { error } = await supabase.from('note_tasks').select('*').limit(1);
            return !error;
          }
        }
      ]
    },
    {
      file: '20250911_all_critical_fixes.sql',
      checks: [
        {
          name: 'folders table',
          test: async () => {
            const { error } = await supabase.from('folders').select('*').limit(1);
            return !error;
          }
        },
        {
          name: 'note_folders table',
          test: async () => {
            const { error } = await supabase.from('note_folders').select('*').limit(1);
            return !error;
          }
        },
        {
          name: 'clipper_inbox table',
          test: async () => {
            const { error } = await supabase.from('clipper_inbox').select('*').limit(1);
            return !error;
          }
        }
      ]
    }
  ];

  for (const migration of migrationChecks) {
    const isSkipped = skippedFiles.some(f => f.includes(migration.file));
    const isActive = activeFiles.includes(migration.file);
    
    console.log(`\n📄 ${migration.file}:`);
    console.log(`   Status: ${isSkipped ? 'SKIPPED' : isActive ? 'ACTIVE' : 'NOT FOUND'}`);
    
    if (!isSkipped) {
      console.log('   Verification:');
      let allPassed = true;
      
      for (const check of migration.checks) {
        const passed = await check.test();
        console.log(`     ${passed ? '✅' : '❌'} ${check.name}`);
        if (!passed) allPassed = false;
      }
      
      verificationResults.push({
        file: migration.file,
        status: isSkipped ? 'SKIPPED' : isActive ? 'ACTIVE' : 'NOT FOUND',
        applied: allPassed ? 'YES' : 'PARTIAL'
      });
    }
  }

  // Check for the problematic migrations
  console.log('\n' + '='.repeat(70));
  console.log('PROBLEMATIC MIGRATIONS CHECK');
  console.log('=' .repeat(70));

  const problematicMigrations = [
    '20250114_audit_extend_rls_policies.sql',
    '20250114_convert_to_jsonb.sql',
    '20250114_create_unique_indexes.sql',
    '20250114_enforce_foreign_key_cascades.sql',
    '20250114_fix_database_settings.sql'
  ];

  console.log('\nThese migrations had conflicts and were skipped:');
  for (const file of problematicMigrations) {
    const isSkipped = skippedFiles.some(f => f.includes(file));
    console.log(`  ${isSkipped ? '⊘ SKIPPED' : '⚠️  ACTIVE'}: ${file}`);
    
    if (!isSkipped && activeFiles.includes(file)) {
      console.log('     ⚠️  This migration is still active but had conflicts!');
    }
  }

  // Final assessment
  console.log('\n' + '='.repeat(70));
  console.log('ASSESSMENT');
  console.log('=' .repeat(70));

  const hasPartialMigrations = verificationResults.some(r => r.applied === 'PARTIAL');
  const hasSkippedCritical = skippedFiles.length > 0;

  if (hasPartialMigrations) {
    console.log('\n❌ CRITICAL: Some migrations are only partially applied!');
    console.log('This means the database is in an inconsistent state.');
  }

  if (hasSkippedCritical) {
    console.log('\n⚠️  WARNING: Some migrations were skipped due to conflicts.');
    console.log('These may contain important updates that are missing.');
  }

  if (!hasPartialMigrations && !hasSkippedCritical) {
    console.log('\n✅ All active migrations appear to be fully applied.');
  }

  // Recommendations
  console.log('\n' + '='.repeat(70));
  console.log('RECOMMENDATIONS');
  console.log('=' .repeat(70));

  if (hasPartialMigrations || hasSkippedCritical) {
    console.log('\n1. Review skipped migrations for critical updates');
    console.log('2. Create a consolidated repair migration');
    console.log('3. Test thoroughly in a staging environment');
    console.log('4. Apply the repair migration to production');
  } else {
    console.log('\n✅ Database appears to be in a consistent state.');
    console.log('However, review the skipped migrations to ensure no critical updates are missing.');
  }

  // Save detailed report
  const report = {
    timestamp: new Date().toISOString(),
    activeFiles,
    skippedFiles,
    verificationResults,
    hasPartialMigrations,
    hasSkippedCritical
  };

  fs.writeFileSync(
    path.join(__dirname, 'migration_status_report.json'),
    JSON.stringify(report, null, 2)
  );

  console.log('\n📄 Detailed report saved to: scripts/migration_status_report.json');
}

checkMigrationStatus().then(() => {
  process.exit(0);
}).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
