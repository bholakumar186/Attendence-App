-- 002_functions_and_policies.sql

-- Function to generate employee id EMP + YYYY + serial (4 digits)
CREATE OR REPLACE FUNCTION get_next_employee_serial(p_year integer)
RETURNS integer AS $$
DECLARE
  next_serial integer;
BEGIN
  LOOP
    -- Try to insert a row for the year; if exists, update last_serial and return
    INSERT INTO employee_id_sequences (year, last_serial)
    VALUES (p_year, 1)
    ON CONFLICT (year)
    DO UPDATE SET last_serial = employee_id_sequences.last_serial + 1
    RETURNING last_serial INTO next_serial;

    IF FOUND THEN
      RETURN next_serial;
    END IF;
  END LOOP;
END;
$$ LANGUAGE plpgsql VOLATILE;

CREATE OR REPLACE FUNCTION generate_employee_id(p_year integer)
RETURNS text AS $$
DECLARE
  serial integer;
  padded text;
BEGIN
  serial := get_next_employee_serial(p_year);
  padded := lpad(serial::text, 4, '0');
  RETURN 'EMP' || p_year::text || padded;
END;
$$ LANGUAGE plpgsql VOLATILE;

-- RPC to mark attendance in
CREATE OR REPLACE FUNCTION mark_attendance_in(
  p_employee_id text,
  p_lat numeric,
  p_lng numeric,
  p_device_info text DEFAULT null
)
RETURNS jsonb AS $$
DECLARE
  rec attendance%ROWTYPE;
  today date := (now() at time zone 'utc')::date;
BEGIN
  -- Lock the attendance row for today if exists
  SELECT * INTO rec FROM attendance
  WHERE employee_id = p_employee_id AND "date" = today
  FOR UPDATE;

  IF rec.id IS NOT NULL THEN
    IF rec.in_time IS NOT NULL THEN
      RAISE EXCEPTION 'IN already marked for today';
    ELSE
      UPDATE attendance SET in_time = now(), location_in = ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography, device_info = jsonb_build_object('in', p_device_info)
      WHERE id = rec.id RETURNING * INTO rec;
    END IF;
  ELSE
    INSERT INTO attendance (employee_id, "date", in_time, location_in, device_info)
    VALUES (p_employee_id, today, now(), ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography, jsonb_build_object('in', p_device_info))
    RETURNING * INTO rec;
  END IF;

  PERFORM pg_notify('attendance_events', jsonb_build_object('type','in','employee_id', p_employee_id, 'record', to_jsonb(rec))::text);

  RETURN jsonb_build_object('status','ok','action','in','record', to_jsonb(rec));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- RPC to mark attendance out
CREATE OR REPLACE FUNCTION mark_attendance_out(
  p_employee_id text,
  p_lat numeric,
  p_lng numeric,
  p_device_info text DEFAULT null
)
RETURNS jsonb AS $$
DECLARE
  rec attendance%ROWTYPE;
  today date := (now() at time zone 'utc')::date;
  total_seconds integer;
BEGIN
  SELECT * INTO rec FROM attendance
  WHERE employee_id = p_employee_id AND "date" = today
  FOR UPDATE;

  IF rec.id IS NULL THEN
    RAISE EXCEPTION 'No IN record for today';
  END IF;

  IF rec.out_time IS NOT NULL THEN
    RAISE EXCEPTION 'OUT already marked for today';
  END IF;

  IF rec.in_time IS NULL THEN
    RAISE EXCEPTION 'IN not found; cannot mark OUT';
  END IF;

  IF now() <= rec.in_time THEN
    RAISE EXCEPTION 'OUT time must be after IN time';
  END IF;

  UPDATE attendance SET out_time = now(), location_out = ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326)::geography, device_info = jsonb_set(COALESCE(device_info,'{}'::jsonb), '{out}', to_jsonb(p_device_info)), total_work_seconds = EXTRACT(EPOCH from (now() - rec.in_time))::integer
  WHERE id = rec.id RETURNING * INTO rec;

  -- Optional flags: late if in_time after 09:15 (server can consider timezone)
  IF rec.in_time::time > '09:15:00'::time THEN
    UPDATE attendance SET late = true WHERE id = rec.id;
  END IF;

  PERFORM pg_notify('attendance_events', jsonb_build_object('type','out','employee_id', p_employee_id, 'record', to_jsonb(rec))::text);

  RETURN jsonb_build_object('status','ok','action','out','record', to_jsonb(rec));
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Monthly attendance summary
CREATE OR REPLACE FUNCTION monthly_attendance_summary(
  p_employee_id text,
  p_year integer,
  p_month integer
)
RETURNS TABLE(
  employee_id text,
  year int,
  month int,
  working_days int,
  present_days int,
  absent_days int,
  total_work_seconds bigint,
  total_work_hours numeric
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p_employee_id as employee_id,
    p_year as year,
    p_month as month,
    (SELECT date_part('days', (date_trunc('month', make_date(p_year, p_month, 1) + interval '1 month') - date_trunc('month', make_date(p_year, p_month, 1))))::int),
    COUNT(CASE WHEN in_time IS NOT NULL THEN 1 END) as present_days,
    (SELECT (date_part('days', (date_trunc('month', make_date(p_year, p_month, 1) + interval '1 month') - date_trunc('month', make_date(p_year, p_month, 1))))::int) - COUNT(CASE WHEN in_time IS NOT NULL THEN 1 END)) as absent_days,
    COALESCE(SUM(total_work_seconds),0) as total_work_seconds,
    ROUND(COALESCE(SUM(total_work_seconds),0) / 3600.0, 2) as total_work_hours
  FROM attendance
  WHERE employee_id = p_employee_id
    AND date_trunc('month', "date") = date_trunc('month', make_date(p_year, p_month, 1))
  GROUP BY employee_id;
END;
$$ LANGUAGE plpgsql STABLE;

-- Notifications channel and optional trigger can be added if you want real-time updates in the client

-- RLS and policies (example: keep broad restrictions here and tighten in prod)
-- Enable row level security
ALTER TABLE attendance ENABLE ROW LEVEL SECURITY;

-- Allow only authenticated users to insert via RPC functions, keep table access restricted
CREATE POLICY "employees_can_see_their_own_attendance" ON attendance
  FOR SELECT
  USING (auth.role() = 'service_role' OR (auth.uid() IS NOT NULL AND employee_id = (SELECT employee_id FROM employees WHERE user_id = auth.uid())));

-- Deny direct inserts/updates from client; only allow server-defined RPCs to mutate
CREATE POLICY "no_direct_write_from_client" ON attendance
  FOR ALL
  USING (auth.role() = 'service_role');

-- Audit trigger
CREATE OR REPLACE FUNCTION log_audit() RETURNS trigger AS $$
BEGIN
  INSERT INTO audit_logs(actor, action, details) VALUES (auth.uid(), TG_OP || ' on ' || TG_TABLE_NAME, row_to_json(NEW));
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER attendance_audit AFTER INSERT OR UPDATE OR DELETE ON attendance
FOR EACH ROW EXECUTE PROCEDURE log_audit();
