--version with recursion
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
-- Recursive CTE to traverse group hierarchy

group_hierarchy as (

    -- Base case: direct members of groups (users or subgroups)
    select
        group_id as top_level_group_id,
        group_id as current_group_id,
        userorgroup_id as member_id,
        1 as level
    from {{ ref('cur_sfdc_groupmember') }}

    union all
    -- Recursive case: members of subgroups
    select
        hier.top_level_group_id,
        member.group_id as current_group_id,
        member.userorgroup_id as member_id,
        hier.level + 1 as level
    from group_hierarchy as hier
    inner join {{ ref('cur_sfdc_groupmember') }} as member
        on hier.member_id = member.group_id
    where hier.level < 5

),

-- Get all users associated with each top-level group
group_users as (

    select
        hier.top_level_group_id as group_id,
        dt_users.email as dynatrace_user_email
    from group_hierarchy as hier
    inner join dynatrace_users as dt_users
        on hier.member_id = dt_users.user_id  -- Member is a user

),

-- Get users from roles within groups
group_role_users as (

    select
        hier.top_level_group_id as group_id,
        role_hier.dynatrace_user_email
    from group_hierarchy as hier
    inner join {{ ref('cur_sfdc_group') }} as sfdc_group
        on hier.member_id = sfdc_group.group_id
    inner join {{ ref('cur_sfdc_userrole') }} as userrole
        on sfdc_group.relatedid = userrole.user_role_id
    inner join {{ ref('int_role_hierarchy_recursion') }} as role_hier
        on userrole.developer_name = role_hier.base_developer_name
    where
        role_hier.hierarchy_type = 'parent_relationship'
        and role_hier.dynatrace_user_email is not null

)
,
-- Combine all user sources
all_group_users as (

    select * from group_users
    union
    select * from group_role_users

),

-- Aggregate users by group
hierarchy_group_regular as (

    select
        accountshare.accountid as sfdc_account_id,
        all_users.dynatrace_user_email
    from {{ ref('cur_sfdc_accountshare') }} as accountshare
    inner join {{ ref('cur_sfdc_group') }} as grps
        on accountshare.userorgroup_id = grps.group_id
    left join all_group_users as all_users
        on grps.group_id = all_users.group_id
    where
        accountshare.userorgroup_id like '00G%' --groups only 
        and lower(grps.type) = 'regular'
)

select distinct
    sfdc_account_id,
    dynatrace_user_email
from hierarchy_group_regular
