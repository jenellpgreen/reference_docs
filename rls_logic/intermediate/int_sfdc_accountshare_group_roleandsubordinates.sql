{{
    config(
        materialized = 'table'
    )
}}

with accountshare_grp as (
    select distinct
        accountid as sfdc_account_id,
        userorgroup_id,
        grp.group_id,
        grp.developer_name,
        grp.relatedid as role_id
    from {{ ref('cur_sfdc_accountshare') }} as accountshare
    inner join {{ ref('cur_sfdc_group') }} as grp
        on accountshare.userorgroup_id = grp.group_id
    where
        userorgroup_id like '00G%' --groups only
        and grp.type = 'RoleAndSubordinatesInternal'
),


role_recursion as (
    select
        base_role_id,
        base_developer_name,
        hierarchy_type,
        hierarchy_role_id,
        hierarchy_developer_name,
        level,
        dynatrace_user_email
    from {{ ref('int_role_hierarchy_recursion') }}
    --where hierarchy_type = 'parent_relationship'
),

account_role_access as (
    select  
        accountshare_grp.sfdc_account_id,
        accountshare_grp.developer_name as shared_group_name,
        accountshare_grp.role_id as shared_role_id,
        role_recursion.hierarchy_type,
        role_recursion.hierarchy_role_id,
        role_recursion.hierarchy_developer_name,
        role_recursion.level,
        role_recursion.dynatrace_user_email
    from accountshare_grp
    inner join role_recursion
        on accountshare_grp.role_id = role_recursion.base_role_id
)

select
    sfdc_account_id,
    shared_group_name,
    hierarchy_type,
    hierarchy_developer_name,
    level,
    dynatrace_user_email
from account_role_access
group by all
