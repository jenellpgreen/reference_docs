{{
    config(
        materialized = 'table'
    )
}}

with

dynatrace_users as (

    select
        user_id,
        userroleid,
        email
    from {{ ref('cur_sfdc_user') }}
    where
        email like '%@dynatrace.com'

),

hierarchy_group_regular as (

    select
        accountshare.accountid as sfdc_account_id,
        array_unique_agg(coalesce(dynatrace_users.email, dynatrace_users_2.email, role_sfdc_user.email)) as dynatrace_user_emails_array,
        grps.developer_name
    from {{ ref('cur_sfdc_accountshare') }} as accountshare
    inner join {{ ref('cur_sfdc_group') }} as grps
        on accountshare.userorgroup_id = grps.group_id
    left join {{ ref('cur_sfdc_groupmember') }} as groupmember
        on grps.group_id = groupmember.group_id
    left join dynatrace_users -- grabs the users within each regular top level group
        on groupmember.userorgroup_id = dynatrace_users.user_id
        --checking to see if a group has other groups within it - only 2 deep, but probably should switch this to a recursive function, just in case they expand on groups later
    left join {{ ref('cur_sfdc_groupmember') }} as grpmember2
        on groupmember.userorgroup_id = grpmember2.group_id
    left join dynatrace_users as dynatrace_users_2 -- grabs the users within 2nd level of groups
        on grpmember2.userorgroup_id = dynatrace_users_2.user_id
    left join {{ ref('cur_sfdc_group') }} as grp2 -- using this to get roles within a group
        on groupmember.userorgroup_id = grp2.group_id
    left join {{ ref('cur_sfdc_userrole') }} as userrole --grabbing associated roles
        on grp2.relatedid = userrole.user_role_id
    left join dynatrace_users as role_sfdc_user -- grabs the users within each role within the group
        on userrole.user_role_id = role_sfdc_user.userroleid
    where
        accountshare.userorgroup_id like '00G%' --groups only 
        and grps.type = 'Regular'
    group by all

),

unique_records as (

    select distinct
        dynatrace_user_emails_array,
        sfdc_account_id
    from hierarchy_group_regular

),

hierarchy_flatten as (

    select
        unique_records.sfdc_account_id,
        f.value as dynatrace_user_email
    from unique_records,
        lateral flatten(input => unique_records.dynatrace_user_emails_array) as f

)

select distinct
    sfdc_account_id,
    dynatrace_user_email::varchar as dynatrace_user_emails
from hierarchy_flatten
