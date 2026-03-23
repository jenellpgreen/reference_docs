{{
    config(
        materialized = 'table'
    )
}}

with

accountshare_grp as (

    select distinct
        accountshare.accountid as sfdc_account_id,
        accountshare.userorgroup_id,
        sfdc_group.group_id,
        sfdc_group.developer_name
    from {{ ref('cur_sfdc_accountshare') }} as accountshare
    inner join {{ ref('cur_sfdc_group') }} as sfdc_group
        on accountshare.userorgroup_id = sfdc_group.group_id
    where
        accountshare.userorgroup_id like '00G%'
        and sfdc_group.type in ('Role')

),

role_recursion as (

    select distinct   --added distinct as there were some duplicated emails
        base_developer_name,
        hierarchy_type,
        hierarchy_role_id,
        hierarchy_developer_name,
        array_unique_agg(dynatrace_user_email) over (partition by base_developer_name, hierarchy_developer_name) as agg
    from {{ ref('int_role_hierarchy_recursion_with_children') }}
    where 
        hierarchy_type = 'parent_relationship'

),

role_recursion_array_union as (

    select distinct
        base_developer_name,
        array_union_agg(agg) over (partition by base_developer_name) as dynatrace_user_email_array
    from role_recursion

),

hierarchy_and_roles as (

    select
        accountshare_grp.sfdc_account_id,
        accountshare_grp.developer_name,
        role_recursion_array_union.dynatrace_user_email_array
    from accountshare_grp
    inner join role_recursion_array_union
        on accountshare_grp.developer_name = role_recursion_array_union.base_developer_name

),

unique_records as (

    select distinct
        dynatrace_user_email_array,
        sfdc_account_id
    from hierarchy_and_roles

),

hierarchy_flatten as (

    select
        unique_records.sfdc_account_id,
        f.value::varchar as dynatrace_user_email
    from unique_records,
        lateral flatten(input => unique_records.dynatrace_user_email_array) as f

)

select distinct
    sfdc_account_id,
    dynatrace_user_email
from hierarchy_flatten
