{{
    config(
        materialized = 'table'
    )
}}

with recursive
-- get all CHILD roles (downward traversal)
role_hierarchy_children as (
    -- Base case: the role itself
    select
        userrole.user_role_id as base_role_id,
        userrole.developer_name as base_developer_name,
        userrole.user_role_id as child_role_id,
        userrole.developer_name as child_developer_name,
        0 as level
    from {{ ref('cur_sfdc_userrole') }} as userrole
    union all
    -- Recursive case: children of children (subordinates)
    select
        h.base_role_id,
        h.base_developer_name,
        userrole.user_role_id as child_role_id,
        userrole.developer_name as child_developer_name,
        h.level - 1 as level
    from role_hierarchy_children as h
    inner join {{ ref('cur_sfdc_userrole') }} as userrole
        on h.child_role_id = userrole.parent_role_id  -- Find roles whose parent is current child
    where h.level > -10
),

-- get all PARENT roles (upward traversal)
role_hierarchy_parents as (
    -- Base case: the role itself
    select
        user_role_id as base_role_id,
        developer_name as base_developer_name,
        user_role_id as parent_role_id,
        developer_name as parent_developer_name,
        0 as level
    from {{ ref('cur_sfdc_userrole') }}
    union all
    -- Recursive case: parents of parents (managers above)
    select
        h.base_role_id,
        h.base_developer_name,
        userrole.parent_role_id,
        parent_userrole.developer_name as parent_developer_name,
        h.level + 1 as level
    from role_hierarchy_parents as h
    inner join {{ ref('cur_sfdc_userrole') }} as userrole
        on h.parent_role_id = userrole.user_role_id
    inner join {{ ref('cur_sfdc_userrole') }} as parent_userrole
        on userrole.parent_role_id = parent_userrole.user_role_id
    where
        userrole.parent_role_id is not null
        and h.level < 10
),

-- combine all
all_role_relationships as (
    -- child relationships (negative levels)
    select
        'child_relationship' as hierarchy_type,
        base_role_id,
        base_developer_name,
        child_role_id as hierarchy_role_id,
        child_developer_name as hierarchy_developer_name,
        level
    from role_hierarchy_children
    where level < 0  -- Only actual children
    union all
    -- parent relationships (positive levels)
    select
        'parent_relationship' as hierarchy_type,
        base_role_id,
        base_developer_name,
        parent_role_id as hierarchy_role_id,
        parent_developer_name as hierarchy_developer_name,
        level
    from role_hierarchy_parents
    where level > 0  -- Only actual parents
    union all
    -- Base role itself (level 0)
    select
        'base_role' as hierarchy_type,
        user_role_id as base_role_id,
        developer_name as base_developer_name,
        user_role_id as hierarchy_role_id,
        developer_name as hierarchy_developer_name,
        0 as level
    from {{ ref('cur_sfdc_userrole') }}
),

-- get users in each role
users as (
    select
        user_id,
        userroleid,
        email
    from {{ ref('cur_sfdc_user') }}
    where
        email like '%@dynatrace.com'
        and userroleid is not null
),

-- roles to users
final as (
    select
        arr.hierarchy_type,
        arr.base_role_id,
        arr.base_developer_name,
        arr.hierarchy_role_id,
        arr.hierarchy_developer_name,
        arr.level,
        u.user_id,
        u.email as dynatrace_user_email
    from all_role_relationships as arr
    left join users as u
        on arr.hierarchy_role_id = u.userroleid
)

select
    hierarchy_type,
    base_role_id,
    base_developer_name,
    hierarchy_role_id,
    hierarchy_developer_name,
    level,
    user_id,
    dynatrace_user_email
from final
