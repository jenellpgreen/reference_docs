{{ config(materialized = 'table') }}

{#
This code is intended to generate the max hierarchy depth level for our employee hierarchy
in order to be able to dynamically produce the needed columns for representing employee hierarchy. This is being done
so that should those depths ever change, we can avoid having to hard code multiple joins.
#}
{%- set max_hierarchy_depth_query %}

select max(hierarchy_depth) from {{ ref('int_sap_employee_census') }}

{%- endset %}

{%- if execute %}

    {% set max_depth = run_query(max_hierarchy_depth_query).columns[0][0]|int %}

{%- else %}

    {% set max_depth = 0 %}

{%- endif %}

with sap_employee_census as (
    select * from {{ ref('int_sap_employee_census') }}
),

final as (
    select
        employee_id,
        employee_name,
        employee_first_name,
        employee_preferred_first_name,
        employee_middle_name,
        employee_last_name,
        work_email_address,
        region,
        company,
        employee_type,
        employee_status,
        job_code,
        job_title,
        business_title,
        job_description,
        career_track,
        job_level,
        job_family,
        job_family_group,
        supervisor_employee_id,
        supervisor_name,
        supervisor_first_name,
        supervisor_middle_name,
        supervisor_last_name,
        supervisor_email_address,
        business_unit,
        division,
        department_code,
        department,
        department_number_name,
        cost_center_number,
        cost_center,
        cost_center_number_name,
        office_location,
        dwm_type,
        is_wfh,
        position_code,
        position_title,
        position_entry_date,
        consolidated_department,
        roll_up_for_bod_pnl,
        sub_bod_pnl,
        exec_bod,
        exec_sub_bod,
        executive_employee_id,
        executive_name,
        executive_first_name,
        executive_middle_name,
        executive_last_name,
        /*
        We have to use these case statements for level 1 as we need variable logic to delineate the CEO vs other individuals
        that may have NO_MANAGER listed as their supervisors for the actual top of the hierarchy. Contractors or previously terminated employees migrated over from UKG
        typically fall into the latter bucket which present problems with recursion.
        */
        case
            when supervisor_employee_id = 'NO_MANAGER' then supervisor_employee_id_array[0]::text
            else supervisor_employee_id_array[1]::text
        end as level_1_employee_id,
        case
            when supervisor_employee_id = 'NO_MANAGER' then supervisor_name_array[0]::text
            else supervisor_name_array[0]::text -- this is intentionally index 0 as the 'NO_MANAGER' supervisor doesn't have an employee name attached to it
        end as level_1_employee_name,
        case
            when supervisor_employee_id = 'NO_MANAGER' then supervisor_email_address_array[0]::text
            else supervisor_email_address_array[0]::text -- this is intentionally index 0 as the 'NO_MANAGER' supervisor doesn't have an email attached to it
        end as level_1_email_address,
        /* This dynamic loop starts off at the level below people with NO_MANAGER (aka level 2 which excludes the CEO and contractors) */
        {%- for depth in range(2, max_depth) %}
            supervisor_employee_id_array[{{ depth }}]::text as level_{{ depth }}_employee_id,
            supervisor_name_array[{{ depth - 1 }}]::text as level_{{ depth }}_employee_name, -- We have to decrement by 1 here as the NO_MANAGER supervisor does not have a name populated
            supervisor_email_address_array[{{ depth - 1 }}]::text as level_{{ depth }}_email_address, -- We have to decrement by 1 here as the NO_MANAGER supervisor does not have an email populated
        {%- endfor %},
        hierarchy_depth,
        date_inserted
    from sap_employee_census
)

select * from final
