{{
    config(
        materialized = 'table'
    )
}}

with

queue_member_roles as (

    select
        accountshare.accountid as sfdc_account_id,
        --accountshare.userorgroup_id,
        --grps.group_id,
        grps.developer_name as queue_name,
        sfdc_role.developer_name as member_role_name,
        --array_agg(distinct sfdc_users.email) as dynatrace_user_emails_array
        sfdc_users.email as member_email
    from {{ ref('cur_sfdc_accountshare') }} as accountshare
    inner join {{ ref('cur_sfdc_group') }} as grps --confirmed all records are found in user table, no nulls
        on accountshare.userorgroup_id = grps.group_id
    left join {{ ref('cur_sfdc_groupmember') }} as groupmember --one group not matching, need to research. 11 records
        on grps.group_id = groupmember.group_id
    inner join {{ ref('cur_sfdc_user') }} as sfdc_users -- inner join as we don't need to grab any groups with no members
        on groupmember.userorgroup_id = sfdc_users.user_id
    inner join {{ ref('cur_sfdc_userrole') }} as sfdc_role 
        on sfdc_users.user_role_id = sfdc_role.user_role_id
    where
        accountshare.userorgroup_id like '00G%' --groups only
        and grps.type = 'Queue'
        and sfdc_users.email ilike '%@dynatrace.com'
        and sfdc_users.user_role_id is not null
    group by all

),

role_hierarchy_expansion as (

    select distinct
        qmr.sfdc_account_id,
        rhr.dynatrace_user_email
    from queue_member_roles as qmr
    inner join {{ ref('int_role_hierarchy_recursion_with_children') }} as rhr
        on qmr.member_role_name = rhr.base_developer_name
    where rhr.hierarchy_type = 'parent_relationship'
        and rhr.dynatrace_user_email is not null
)

select
    sfdc_account_id,
    dynatrace_user_email
from role_hierarchy_expansion