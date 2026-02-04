require("dotenv").config();
const express = require("express");
const bodyParser = require("body-parser");
const { createClient } = require("@supabase/supabase-js");
const cors = require("cors");

const app = express();
app.use(cors()); // Allow requests from your Flutter app
app.use(bodyParser.json());

const SUPABASE_URL = process.env.SUPABASE_URL;
const SUPABASE_SERVICE_ROLE_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
const ADMIN_API_KEY = process.env.ADMIN_API_KEY;

const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, {
  auth: { persistSession: false },
});

// Middleware to protect admin endpoints
function requireAdminApiKey(req, res, next) {
  const key = req.headers["x-admin-api-key"];
  if (!key || key !== ADMIN_API_KEY)
    return res.status(401).json({ error: "Unauthorized" });
  next();
}

// Create employee endpoint (admin only)
app.post("/admin/create-employee", requireAdminApiKey, async (req, res) => {
  try {
    console.log("Create Employee Request:", req.body);
    const { name, email, password, phone, role } = req.body;
    if (!name || !email || !password)
      return res.status(400).json({ error: "Missing fields" });

    // 1. Create auth user using service role key
    const { data: userData, error: createUserErr } =
      await supabase.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: name, phone },
      });
    if (createUserErr) throw createUserErr;

    const userId = userData.id;
    const year = new Date().getFullYear();

    // 2. Generate Employee ID using RPC
    const { data: genData, error: genErr } = await supabase.rpc(
      "generate_employee_id",
      { p_year: year },
    );
    if (genErr) throw genErr;
    const employeeId = genData;

    // 3. Insert into employees table
    const { data: emp, error: empErr } = await supabase
      .from("employees")
      .insert([
        {
          employee_id: employeeId,
          user_id: userId,
          full_name: name,
          email,
          phone,
          role: role || "employee",
        },
      ])
      .select()
      .single();
    if (empErr) throw empErr;

    res.json({ success: true, employee: emp });
  } catch (e) {
    console.error(e);
    res.status(500).json({ error: e.message || e });
  }
});

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => console.log("Admin API listening on port", PORT));
