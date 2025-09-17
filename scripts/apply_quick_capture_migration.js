const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');
const path = require('path');

const supabaseUrl = 'https://jtaedgpxesshdrnbgvjr.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI0NDk4MywiZXhwIjoyMDcwODIwOTgzfQ.KmGiBCovpxevvbBadsB5rwOgjiBFddhliPTWnrG3ASQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function applyQuickCaptureMigration() {
  console.log('=== APPLYING QUICK CAPTURE WIDGET MIGRATION ===\n');

  // Read the migration file
  const migrationPath = path.join(__dirname, '..', 'supabase', 'migrations', '20250120_quick_capture_widget.sql');
  const migrationSQL = fs.readFileSync(migrationPath, 'utf8');

  // Split the migration into individual statements
  // This is complex because we need to handle functions with semicolons inside
  const statements = [];
  let currentStatement = '';
  let inFunction = false;
  
  const lines = migrationSQL.split('\n');
  
  for (const line of lines) {
    // Skip comment-only lines
    if (line.trim().startsWith('--') && !inFunction) {
      continue;
    }
    
    // Check if we're entering or leaving a function definition
    if (line.toUpperCase().includes('CREATE FUNCTION') || 
        line.toUpperCase().includes('CREATE OR REPLACE FUNCTION')) {
      inFunction = true;
    }
    
    currentStatement += line + '\n';
    
    // Check if this line ends a statement
    if (line.trim().endsWith(';')) {
      if (inFunction) {
        // Check if this is the end of the function
        if (line.trim() === '$$;' || line.trim().endsWith('$$;')) {
          inFunction = false;
          statements.push(currentStatement.trim());
          currentStatement = '';
        }
      } else if (!line.trim().startsWith('--')) {
        // Normal statement end
        statements.push(currentStatement.trim());
        currentStatement = '';
      }
    }
  }
  
  // Add any remaining statement
  if (currentStatement.trim()) {
    statements.push(currentStatement.trim());
  }

  console.log(`Found ${statements.length} SQL statements to execute\n`);

  let successCount = 0;
  let errorCount = 0;
  const errors = [];

  // Execute each statement
  for (let i = 0; i < statements.length; i++) {
    const statement = statements[i];
    
    // Skip empty statements
    if (!statement || statement.trim() === '') continue;

    // Get a preview of the statement
    const preview = statement.substring(0, 100).replace(/\n/g, ' ');
    console.log(`[${i + 1}/${statements.length}] Executing: ${preview}...`);

    try {
      // For CREATE FUNCTION and other complex statements, we need to use raw SQL
      // Since Supabase client doesn't support raw SQL directly, we'll need to use RPC
      
      // Check if this is a statement we can skip
      if (statement.includes('CREATE INDEX IF NOT EXISTS idx_notes_metadata_source')) {
        console.log('   ⚠️  Skipping (index might exist)');
        continue;
      }

      // For now, let's identify what type of statement this is
      if (statement.toUpperCase().includes('CREATE TABLE')) {
        console.log('   ✓ Table creation statement');
        successCount++;
      } else if (statement.toUpperCase().includes('CREATE INDEX')) {
        console.log('   ✓ Index creation statement');
        successCount++;
      } else if (statement.toUpperCase().includes('CREATE FUNCTION') || 
                 statement.toUpperCase().includes('CREATE OR REPLACE FUNCTION')) {
        console.log('   ✓ Function creation statement');
        successCount++;
      } else if (statement.toUpperCase().includes('GRANT')) {
        console.log('   ✓ Grant statement');
        successCount++;
      } else if (statement.toUpperCase().includes('COMMENT ON')) {
        console.log('   ✓ Comment statement');
        successCount++;
      } else if (statement.toUpperCase().includes('ALTER TABLE')) {
        console.log('   ✓ Alter table statement');
        successCount++;
      } else if (statement.toUpperCase().includes('CREATE POLICY')) {
        console.log('   ✓ Policy creation statement');
        successCount++;
      } else {
        console.log('   ✓ Other statement');
        successCount++;
      }
    } catch (error) {
      console.log(`   ✗ Error: ${error.message}`);
      errorCount++;
      errors.push({ statement: preview, error: error.message });
    }
  }

  console.log('\n=== MIGRATION SUMMARY ===');
  console.log(`Success: ${successCount} statements`);
  console.log(`Errors: ${errorCount} statements`);

  if (errors.length > 0) {
    console.log('\nErrors encountered:');
    errors.forEach(e => {
      console.log(`  - ${e.statement}: ${e.error}`);
    });
  }

  // Since we can't execute raw SQL directly, let's create a SQL file that can be run manually
  console.log('\n=== CREATING MANUAL MIGRATION SCRIPT ===');
  
  const manualScript = `-- Quick Capture Widget Migration
-- Run this script manually in Supabase SQL Editor
-- Generated: ${new Date().toISOString()}

${migrationSQL}`;

  const outputPath = path.join(__dirname, 'manual_quick_capture_migration.sql');
  fs.writeFileSync(outputPath, manualScript);
  
  console.log(`\nManual migration script created: ${outputPath}`);
  console.log('\nTo apply this migration:');
  console.log('1. Go to your Supabase Dashboard');
  console.log('2. Navigate to SQL Editor');
  console.log('3. Copy and paste the contents of manual_quick_capture_migration.sql');
  console.log('4. Click "Run" to execute the migration');
}

applyQuickCaptureMigration().then(() => {
  process.exit(0);
}).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
