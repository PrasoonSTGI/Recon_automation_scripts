/* clone_job.sql ---------------------------------------------------- */
CREATE OR REPLACE FUNCTION public.clone_job(
    p_old_job_name   text,
    p_new_job_name   text,
    p_new_description text DEFAULT NULL
)
RETURNS bigint
LANGUAGE plpgsql
AS $$
DECLARE
    old_job   fm_job%ROWTYPE;
    new_job_id bigint;
BEGIN
    SELECT * INTO old_job
      FROM fm_job
     WHERE name = p_old_job_name;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'clone_job(): job "%" not found', p_old_job_name;
    END IF;

    IF EXISTS (SELECT 1 FROM fm_job WHERE name = p_new_job_name) THEN
        RAISE EXCEPTION 'clone_job(): job "%" already exists', p_new_job_name;
    END IF;

    INSERT INTO fm_job (
        name, description, job_parms, test_mode, precondition_sql,
        notes, log_on_precondition_trigger, minutes_saved, include_all_runs
    )
    SELECT  p_new_job_name,
            COALESCE(p_new_description, old_job.description),
            old_job.job_parms, old_job.test_mode, old_job.precondition_sql,
            old_job.notes,  old_job.log_on_precondition_trigger,
            old_job.minutes_saved, old_job.include_all_runs
    RETURNING id INTO new_job_id;

    INSERT INTO fm_action (
        fm_job_id, seq, is_error_handler, action_type, action_parms,
        precondition_sql, precondition_env, log_to_wh, description,
        dynamic_action_sql, notes
    )
    SELECT  new_job_id, seq, is_error_handler, action_type, action_parms,
            precondition_sql, precondition_env, log_to_wh, description,
            dynamic_action_sql, notes
      FROM fm_action
     WHERE fm_job_id = old_job.id;

    RETURN new_job_id;
END;
$$;
