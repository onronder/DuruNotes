const fs = require('fs');
const path = require('path');

function analyzeSkippedMigrations() {
  console.log('=' .repeat(70));
  console.log('ANALYSIS OF SKIPPED MIGRATIONS - CRITICAL UPDATES MISSING');
  console.log('=' .repeat(70));

  const migrationsDir = path.join(__dirname, '..', 'supabase', 'migrations');
  
  const skippedMigrations = [
    '20250114_audit_extend_rls_policies.sql.skip',
    '20250114_convert_to_jsonb.sql.skip',
    '20250114_create_unique_indexes.sql.skip',
    '20250114_enforce_foreign_key_cascades.sql.skip',
    '20250114_fix_database_settings.sql.skip',
    '20250117_fix_clipper_inbox_structure.sql.skip',
    '20250119_note_tasks.sql.skip'
  ];

  const criticalUpdates = [];
  const importantUpdates = [];
  const minorUpdates = [];

  for (const file of skippedMigrations) {
    const filePath = path.join(migrationsDir, file);
    
    if (fs.existsSync(filePath)) {
      const content = fs.readFileSync(filePath, 'utf8');
      
      console.log(`\n📄 ${file.replace('.skip', '')}:`);
      console.log('-'.repeat(50));
      
      // Analyze what this migration does
      const analysis = analyzeMigrationContent(content, file);
      
      console.log('Purpose:', analysis.purpose);
      console.log('Critical Level:', analysis.level);
      console.log('Key Changes:');
      analysis.changes.forEach(change => {
        console.log(`  - ${change}`);
        
        // Categorize updates
        if (analysis.level === 'CRITICAL') {
          criticalUpdates.push({ file: file.replace('.skip', ''), change });
        } else if (analysis.level === 'IMPORTANT') {
          importantUpdates.push({ file: file.replace('.skip', ''), change });
        } else {
          minorUpdates.push({ file: file.replace('.skip', ''), change });
        }
      });
    }
  }

  // Summary
  console.log('\n' + '='.repeat(70));
  console.log('SUMMARY OF MISSING UPDATES');
  console.log('=' .repeat(70));

  console.log('\n❌ CRITICAL UPDATES MISSING:');
  if (criticalUpdates.length === 0) {
    console.log('   None');
  } else {
    criticalUpdates.forEach(u => {
      console.log(`   - ${u.change} (from ${u.file})`);
    });
  }

  console.log('\n⚠️  IMPORTANT UPDATES MISSING:');
  if (importantUpdates.length === 0) {
    console.log('   None');
  } else {
    importantUpdates.forEach(u => {
      console.log(`   - ${u.change} (from ${u.file})`);
    });
  }

  console.log('\n📝 MINOR UPDATES MISSING:');
  if (minorUpdates.length === 0) {
    console.log('   None');
  } else {
    minorUpdates.slice(0, 5).forEach(u => {
      console.log(`   - ${u.change} (from ${u.file})`);
    });
    if (minorUpdates.length > 5) {
      console.log(`   ... and ${minorUpdates.length - 5} more`);
    }
  }

  // Generate repair requirements
  console.log('\n' + '='.repeat(70));
  console.log('REPAIR REQUIREMENTS');
  console.log('=' .repeat(70));

  const repairRequirements = [];

  // Check specific critical items
  if (skippedMigrations.includes('20250119_note_tasks.sql.skip')) {
    console.log('\n1. NOTE_TASKS TABLE:');
    console.log('   ⚠️  The note_tasks table migration was skipped');
    console.log('   However, audit shows the table EXISTS');
    console.log('   → Verify table structure matches expected schema');
    repairRequirements.push('Verify note_tasks table structure');
  }

  if (skippedMigrations.includes('20250114_convert_to_jsonb.sql.skip')) {
    console.log('\n2. JSONB CONVERSION:');
    console.log('   ⚠️  JSONB conversion was skipped');
    console.log('   Current state: metadata columns are already JSONB');
    console.log('   → No action needed');
  }

  if (skippedMigrations.includes('20250114_create_unique_indexes.sql.skip')) {
    console.log('\n3. UNIQUE INDEXES:');
    console.log('   ❌ Unique constraint migrations were skipped');
    console.log('   → Need to verify/add unique constraints');
    repairRequirements.push('Add missing unique constraints');
  }

  if (skippedMigrations.includes('20250114_enforce_foreign_key_cascades.sql.skip')) {
    console.log('\n4. FOREIGN KEY CASCADES:');
    console.log('   ❌ CASCADE rules might be missing');
    console.log('   → Need to verify/add CASCADE rules');
    repairRequirements.push('Add CASCADE rules to foreign keys');
  }

  if (skippedMigrations.includes('20250114_audit_extend_rls_policies.sql.skip')) {
    console.log('\n5. RLS POLICIES:');
    console.log('   ⚠️  Extended RLS policies were skipped');
    console.log('   Current state: Basic RLS is working');
    console.log('   → May need to add comprehensive policies');
    repairRequirements.push('Review and extend RLS policies');
  }

  return { criticalUpdates, importantUpdates, minorUpdates, repairRequirements };
}

function analyzeMigrationContent(content, filename) {
  const analysis = {
    purpose: '',
    level: 'MINOR',
    changes: []
  };

  // Determine purpose
  if (filename.includes('note_tasks')) {
    analysis.purpose = 'Create note_tasks table for task management';
    analysis.level = 'CRITICAL';
    if (content.includes('CREATE TABLE')) {
      analysis.changes.push('Create note_tasks table');
    }
  } else if (filename.includes('convert_to_jsonb')) {
    analysis.purpose = 'Convert JSON columns to JSONB for performance';
    analysis.level = 'IMPORTANT';
    if (content.includes('ALTER TABLE') && content.includes('TYPE jsonb')) {
      analysis.changes.push('Convert metadata columns to JSONB');
    }
  } else if (filename.includes('create_unique_indexes')) {
    analysis.purpose = 'Add unique constraints to prevent duplicates';
    analysis.level = 'CRITICAL';
    if (content.includes('CREATE UNIQUE INDEX')) {
      analysis.changes.push('Add unique constraints');
    }
  } else if (filename.includes('enforce_foreign_key_cascades')) {
    analysis.purpose = 'Add CASCADE rules for data integrity';
    analysis.level = 'CRITICAL';
    if (content.includes('ON DELETE CASCADE')) {
      analysis.changes.push('Add CASCADE delete rules');
    }
  } else if (filename.includes('audit_extend_rls_policies')) {
    analysis.purpose = 'Comprehensive RLS policy coverage';
    analysis.level = 'IMPORTANT';
    if (content.includes('CREATE POLICY')) {
      analysis.changes.push('Extended RLS policies');
    }
  } else if (filename.includes('fix_database_settings')) {
    analysis.purpose = 'Optimize database settings';
    analysis.level = 'MINOR';
    analysis.changes.push('Database configuration updates');
  } else if (filename.includes('fix_clipper_inbox_structure')) {
    analysis.purpose = 'Fix clipper inbox table structure';
    analysis.level = 'IMPORTANT';
    analysis.changes.push('Clipper inbox structure fixes');
  }

  // Extract specific changes from content
  const createTableMatches = content.match(/CREATE TABLE[^;]+/gi) || [];
  createTableMatches.forEach(match => {
    const tableName = match.match(/CREATE TABLE\s+(?:IF NOT EXISTS\s+)?(?:public\.)?(\w+)/i)?.[1];
    if (tableName) {
      analysis.changes.push(`Create table: ${tableName}`);
    }
  });

  const createIndexMatches = content.match(/CREATE\s+(?:UNIQUE\s+)?INDEX[^;]+/gi) || [];
  createIndexMatches.forEach(match => {
    const indexName = match.match(/INDEX\s+(?:IF NOT EXISTS\s+)?(\w+)/i)?.[1];
    if (indexName) {
      const isUnique = match.includes('UNIQUE');
      analysis.changes.push(`${isUnique ? 'Unique index' : 'Index'}: ${indexName}`);
    }
  });

  const alterTableMatches = content.match(/ALTER TABLE[^;]+/gi) || [];
  alterTableMatches.forEach(match => {
    const tableName = match.match(/ALTER TABLE\s+(?:public\.)?(\w+)/i)?.[1];
    if (tableName) {
      if (match.includes('ADD CONSTRAINT')) {
        analysis.changes.push(`Add constraint on: ${tableName}`);
      } else if (match.includes('TYPE')) {
        analysis.changes.push(`Change column type in: ${tableName}`);
      } else {
        analysis.changes.push(`Alter table: ${tableName}`);
      }
    }
  });

  return analysis;
}

const result = analyzeSkippedMigrations();

// Save analysis
fs.writeFileSync(
  path.join(__dirname, 'skipped_migrations_analysis.json'),
  JSON.stringify(result, null, 2)
);

console.log('\n📄 Analysis saved to: scripts/skipped_migrations_analysis.json');
console.log('\n🔧 Next step: Create a consolidated repair migration');
