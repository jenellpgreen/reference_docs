{{
    config(
        materialized = 'table'
    )
}}

with

direct_user_shares as (
    select distinct
        accountshare.accountid as sfdc_account_id,
        sfdc_users.email as dynatrace_user_email,
        sfdc_users.user_role_id
    from {{ ref('cur_sfdc_accountshare') }} as accountshare
    inner join {{ ref('cur_sfdc_user') }} as sfdc_users -- confirmed all records are found in user table, no nulls
        on accountshare.userorgroup_id = sfdc_users.user_id

    where
        accountshare.userorgroup_id like '005%' --direct users only 
        and sfdc_users.email ilike '%@dynatrace.com'
        and sfdc_users.user_role_id is not null

),

user_roles as (

    select
        direct_users.sfdc_account_id,
        direct_users.dynatrace_user_email,
        sfdc_role.developer_name
    from direct_user_shares as direct_users
    inner join {{ ref('cur_sfdc_userrole') }} as sfdc_role
        on direct_users.user_role_id = sfdc_role.user_role_id
),

role_hierarchy_expansion as (

    select distinct --removing duplicates, as sharing can be done through different means
        user_roles.sfdc_account_id,
        role_hier.dynatrace_user_email
    from user_roles
    inner join {{ ref('int_role_hierarchy_recursion_with_children') }} as role_hier
        on user_roles.developer_name = role_hier.base_developer_name
    where
        role_hier.hierarchy_type = 'parent_relationship'
        and role_hier.dynatrace_user_email is not null

),

direct_users as (

    select distinct
        sfdc_account_id,
        dynatrace_user_email
    from direct_user_shares
),

all_users as (

    select * from role_hierarchy_expansion
    union
    select * from direct_users

)

select distinct
    sfdc_account_id,
    dynatrace_user_email
from all_users
