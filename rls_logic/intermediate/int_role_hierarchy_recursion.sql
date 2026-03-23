/*recursively grab all child roles of a given role */
{{
    config(
        materialized = 'table'
    )
}}

with recursive
role_hierarchy_children as (
    select
        userrole.parent_role_id as base_role_id,
        userrole.user_role_id as child_role_id,
        userrole.name as role_name,
        1 as level,
        userrole.parent_role_id as inherited_from_role
    from {{ ref('cur_sfdc_userrole') }} as userrole

    union all

    select
        userrole.parent_role_id as base_role_id,
        h.child_role_id,
        h.role_name,
        h.level + 1,
        h.inherited_from_role

    from role_hierarchy_children as h
    inner join {{ ref('cur_sfdc_userrole') }} as userrole
        on h.base_role_id = userrole.user_role_id
),


/*recursively grab all parent roles of a given role */
role_hierarchy_parents as (
    select
        user_role_id as base_role_id,
        user_role_id as parent_role_id,
        name as parent_role_name,
        1 as level,
        user_role_id as inherited_child_role

    from {{ ref('cur_sfdc_userrole') }}

    union all

    select
        userrole.user_role_id as base_role_id,
        h.parent_role_id,
        h.parent_role_name,
        h.level + 1,
        h.inherited_child_role

    from role_hierarchy_parents as h
    inner join {{ ref('cur_sfdc_userrole') }} as userrole
        on h.base_role_id = userrole.parent_role_id
),

/* union the children rows with the parents roles */
parents_and_children as (
   select
        'child_relationship' as hierarchy_type, -- this will allow us to grab only child or only parent records
        base_role_id,
        child_role_id as hierarchy_role_id,
        role_name as hierarchy_role_name,
        level * -1 as level,
        inherited_from_role as inherited_role_id
    from role_hierarchy_children

    union 

    select
        'parent_relationship' as hierarchy_type,
        base_role_id,
        parent_role_id as hierarchy_role_id,
        parent_role_name as hierarchy_role_name,
        level,
        inherited_child_role as inherited_role_id
    from role_hierarchy_parents
),

dynatrace_users as (
    select
        user_id,
        userroleid,
        email
    from {{ ref('cur_sfdc_user') }}
    where
        email like '%@dynatrace.com'
        and userroleid is not null
),

final_role_hierarchy as (
    select
        h.hierarchy_type,
        h.base_role_id,
        base_userrole.developer_name as base_developer_name,
        h.hierarchy_role_id,
        hierarchy_userrole.developer_name as hierarchy_developer_name,
        h.level,
        inherited_role_id,
        --array_agg(distinct sfdc_users.email) as dynatrace_user_emails_array
        sfdc_users.email as dynatrace_user_email
    from parents_and_children as h
    inner join {{ ref('cur_sfdc_userrole') }} as base_userrole
        on h.base_role_id = base_userrole.user_role_id
    left join {{ ref('cur_sfdc_userrole') }} as hierarchy_userrole --may not have a parent or child if it's first or last level
        on h.hierarchy_role_id = hierarchy_userrole.user_role_id
    left join dynatrace_users as sfdc_users
        on h.hierarchy_role_id = sfdc_users.userroleid
    --group by all
)

select *
from final_role_hierarchy
