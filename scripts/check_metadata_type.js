const { createClient } = require('@supabase/supabase-js');

const supabaseUrl = 'https://jtaedgpxesshdrnbgvjr.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp0YWVkZ3B4ZXNzaGRybmJndmpyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1NTI0NDk4MywiZXhwIjoyMDcwODIwOTgzfQ.KmGiBCovpxevvbBadsB5rwOgjiBFddhliPTWnrG3ASQ';

const supabase = createClient(supabaseUrl, supabaseKey);

async function checkMetadataType() {
  console.log('=== CHECKING METADATA COLUMN TYPE ===\n');

  // Get a sample note to check the data type
  const { data, error } = await supabase
    .from('notes')
    .select('id, encrypted_metadata')
    .limit(1);

  if (error) {
    console.log('Error:', error);
    return;
  }

  console.log('Sample note:', data[0]);
  console.log('encrypted_metadata type:', typeof data[0]?.encrypted_metadata);
  
  if (data[0]?.encrypted_metadata) {
    console.log('Is it a string?', typeof data[0].encrypted_metadata === 'string');
    console.log('Is it an object?', typeof data[0].encrypted_metadata === 'object');
    
    // Try to parse if it's a string
    if (typeof data[0].encrypted_metadata === 'string') {
      try {
        const parsed = JSON.parse(data[0].encrypted_metadata);
        console.log('Can be parsed as JSON:', true);
        console.log('Parsed content:', parsed);
      } catch (e) {
        console.log('Cannot be parsed as JSON:', e.message);
      }
    }
  }

  // Check the table structure
  console.log('\n=== CHECKING TABLE STRUCTURE ===');
  
  // Try different query approaches
  console.log('\n1. Testing TEXT column operations:');
  const { data: textTest, error: textError } = await supabase
    .from('notes')
    .select('id')
    .not('encrypted_metadata', 'is', null)
    .limit(1);
  
  console.log('   TEXT null check:', textError ? `Error: ${textError.message}` : 'Works');

  console.log('\n2. Testing JSONB operations:');
  const { data: jsonbTest, error: jsonbError } = await supabase
    .from('notes')
    .select('id')
    .filter('encrypted_metadata->source', 'eq', 'widget')
    .limit(1);
  
  console.log('   JSONB arrow operator:', jsonbError ? `Error: ${jsonbError.message}` : 'Works');

  console.log('\n3. Testing JSONB ->> operator:');
  const { data: jsonbTextTest, error: jsonbTextError } = await supabase
    .from('notes')
    .select('id')
    .filter('encrypted_metadata->>source', 'eq', 'widget')
    .limit(1);
  
  console.log('   JSONB ->> operator:', jsonbTextError ? `Error: ${jsonbTextError.message}` : 'Works');

  console.log('\n=== CONCLUSION ===');
  console.log('The encrypted_metadata column appears to be TEXT, not JSONB.');
  console.log('We need to either:');
  console.log('1. Convert it to JSONB first');
  console.log('2. Modify the migration to work with TEXT column');
  console.log('3. Use a different approach for indexing');
}

checkMetadataType().then(() => {
  process.exit(0);
}).catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
