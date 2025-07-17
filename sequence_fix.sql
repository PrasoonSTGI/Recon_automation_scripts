-- 1️⃣  Fix the job table
SELECT setval(
         'fm_job_id_seq',   -- sequence name
         (SELECT COALESCE(MAX(id),0) FROM fm_job)+1,
         false   -- false = next nextval() returns exactly this value
       );

-- 2️⃣  (Optional but recommended) do the same for fm_action
SELECT setval(
         'fm_action_id_seq',
         (SELECT COALESCE(MAX(id),0) FROM fm_action)+1,
         false
       );
