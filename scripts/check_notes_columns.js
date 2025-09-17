const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://jtaedgpxesshdrnbgvjr.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI0NDk4MywiZXhwIjoyMDcwODIwOTgzfQ.KmGiBCovpxevvbBadsB5rwOgjiBFddhliPTWnrG3ASQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkNotesColumns() {
  console.log('=== CHECKING NOTES TABLE COLUMNS ===\n');

  // Get a sample note to see what columns exist
  const { data, error } = await supabase
    .from('notes')
    .select('*')
    .limit(1);

  if (error) {
    console.log('Error:', error);
    return;
  }

  if (data && data.length > 0) {
    console.log('Available columns in notes table:');
    Object.keys(data[0]).forEach(col => {
      console.log(`  - ${col}: ${typeof data[0][col]}`);
    });
  } else {
    console.log('No notes found in table');
  }
}

checkNotesColumns().then(() => {
  process.exit(0);
}).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
