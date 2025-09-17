const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://jtaedgpxesshdrnbgvjr.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI0NDk4MywiZXhwIjoyMDcwODIwOTgzfQ.KmGiBCovpxevvbBadsB5rwOgjiBFddhliPTWnrG3ASQ';

const supabase = createClient(supabaseUrl, supabaseKey, {
  db: { schema: 'supabase_migrations' }
});

async function checkMigrations() {
  console.log('=== MIGRATION STATUS CHECK ===\n');

  // Check migration history in supabase_migrations schema
  const { data: migrations, error } = await supabase
    .from('schema_migrations')
    .select('*')
    .order('version', { ascending: false });
  
  if (error) {
    console.log('Error accessing migrations:', error.message);
  } else {
    console.log('Applied migrations:');
    migrations.forEach(m => {
      console.log(`  - ${m.version}: ${m.name || 'unnamed'}`);
    });
  }

  // List local migrations
  const fs = require('fs');
  const path = require('path');
  const migrationsDir = path.join(__dirname, '..', 'supabase', 'migrations');
  
  console.log('\nLocal migration files:');
  const files = fs.readdirSync(migrationsDir).filter(f => f.endsWith('.sql')).sort();
  files.forEach(f => {
    const version = f.split('_')[0];
    console.log(`  - ${version}: ${f}`);
  });

  // Compare
  if (migrations) {
    const appliedVersions = new Set(migrations.map(m => m.version));
    const localVersions = files.map(f => f.split('_')[0]);
    
    console.log('\nMigrations NOT applied:');
    localVersions.forEach(version => {
      if (!appliedVersions.has(version)) {
        const fileName = files.find(f => f.startsWith(version));
        console.log(`  - ${version}: ${fileName}`);
      }
    });
  }
}

checkMigrations().then(() => {
  process.exit(0);
}).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
