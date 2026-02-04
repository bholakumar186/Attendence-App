require('dotenv').config();
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  process.env.SUPABASE_URL,
  process.env.SUPABASE_SERVICE_ROLE_KEY,
  { auth: { persistSession: false } }
);

async function main() {
  // 1. Correctly destructure the 'user' object from 'data'
  const { data: { user }, error: uErr } = await supabase.auth.admin.createUser({
    email: 'admin@transgulfpower.com',
    password: '123456789',
    email_confirm: true,
    user_metadata: { full_name: 'System Admin', phone: '1234567890' }
  });

  if (uErr) throw new Error(`Auth Error: ${uErr.message}`);

  const userId = user.id;
  const year = new Date().getFullYear();

  // 2. Handle potential errors from the RPC call
  const { data: employeeId, error: rpcErr } = await supabase.rpc('generate_employee_id', { p_year: year });
  if (rpcErr) throw new Error(`RPC Error: ${rpcErr.message}`);

  // 3. Insert into the employees table and check for errors
  const { error: iErr } = await supabase.from('employees').insert([{
    employee_id: employeeId,
    user_id: userId,
    full_name: 'System Admin', // Updated to match user_metadata
    email: 'admin@transgulfpower.com',
    phone: '1234567890',
    role: 'admin'
  }]);

  if (iErr) throw new Error(`Insert Error: ${iErr.message}`);

  console.log('✅ Admin successfully created with ID:', userId);
}

main().catch((err) => {
  console.error('❌ Script failed:', err.message);
  process.exit(1);
});