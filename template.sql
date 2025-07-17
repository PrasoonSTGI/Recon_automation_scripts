UPDATE fm_action
SET dynamic_action_sql = $$
select replace(replace(replace(action_parms, 'FILE_DATE', FILE_DATE), 'START_DATE', START_DATE), 'END_DATE', END_DATE)
from fm_action a,
(select 
    to_char(current_date, 'yyyyMMdd') FILE_DATE, 
    to_char(current_date-1,'yyyy/MM/dd') START_DATE, 
    to_char(current_date, 'yyyy/MM/dd') END_DATE
) 
FOO 
where a.id = 4
$$
WHERE id = 4;

UPDATE fm_action
SET dynamic_action_sql = $$
select replace(replace(replace(action_parms, 'FILE_DATE', FILE_DATE), 'START_DATE', START_DATE), 'END_DATE', END_DATE)
from fm_action a,
(select
    to_char(current_date-1, 'yyyyMMdd') FILE_DATE,  
    to_char(current_date-1,'yyyy/MM/dd') START_DATE,  
    to_char(current_date, 'yyyy/MM/dd') END_DATE
) 
FOO 
where a.id = 7
$$
WHERE id = 7;
