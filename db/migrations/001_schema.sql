-- 001_schema.sql
-- Tables for Employee Attendance Management

-- Extension for UUID and geospatial
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- Employees table
CREATE TABLE IF NOT EXISTS employees (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id text UNIQUE NOT NULL, -- EMPYYYYXXXX
  user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  full_name text NOT NULL,
  email text,
  phone text,
  role text NOT NULL DEFAULT 'employee', -- employee or custom
  active boolean NOT NULL DEFAULT true,
  date_of_joining date,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_employees_employee_id ON employees(employee_id);

-- Sequence table for employee serials per year
CREATE TABLE IF NOT EXISTS employee_id_sequences (
  year integer PRIMARY KEY,
  last_serial integer NOT NULL DEFAULT 0
);

-- Attendance table
CREATE TABLE IF NOT EXISTS attendance (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  employee_id text NOT NULL REFERENCES employees(employee_id) ON DELETE CASCADE,
  "date" date NOT NULL,
  in_time timestamptz,
  out_time timestamptz,
  total_work_seconds integer,
  late boolean DEFAULT false,
  early_out boolean DEFAULT false,
  location_in geography(POINT,4326),
  location_out geography(POINT,4326),
  device_info jsonb,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now(),
  UNIQUE (employee_id, "date")
);

CREATE INDEX IF NOT EXISTS idx_attendance_employee_date ON attendance(employee_id, "date");

-- Audit logs
CREATE TABLE IF NOT EXISTS audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor uuid,
  action text NOT NULL,
  details jsonb,
  created_at timestamptz DEFAULT now()
);

-- Trigger helper for updated_at
CREATE OR REPLACE FUNCTION trigger_update_timestamp()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER employees_update_ts BEFORE UPDATE ON employees
FOR EACH ROW EXECUTE PROCEDURE trigger_update_timestamp();

CREATE TRIGGER attendance_update_ts BEFORE UPDATE ON attendance
FOR EACH ROW EXECUTE PROCEDURE trigger_update_timestamp();
