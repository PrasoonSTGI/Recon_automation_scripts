-- 1️⃣  Fix the job table
SELECT setval(
         pg_get_serial_sequence('fm_job','id'),   -- sequence name
         (SELECT COALESCE(MAX(id),0) FROM fm_job)+1,
         false   -- false = next nextval() returns exactly this value
       );

-- 2️⃣  (Optional but recommended) do the same for fm_action
SELECT setval(
         pg_get_serial_sequence('fm_action','id'),
         (SELECT COALESCE(MAX(id),0) FROM fm_action)+1,
         false
       );
