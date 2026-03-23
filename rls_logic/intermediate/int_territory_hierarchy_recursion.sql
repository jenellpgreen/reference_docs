/*recursively grab all parent roles of a given role */
{{
    config(
        materialized = 'table'
    )
}}

with territory_hierarchy_parents as (
    select
        territory_2_id as base_territory_id,
        territory_2_id as parent_territory_id,
        developer_name as parent_territory_name,
        1 as level,
        territory_2_id as inherited_child_territory

    from {{ ref('cur_sfdc_territory2') }}

    union all

    select
        territory.territory_2_id as base_territory_id,
        h.parent_territory_id,
        h.parent_territory_name,
        h.level + 1,
        h.inherited_child_territory

    from territory_hierarchy_parents as h
    inner join {{ ref('cur_sfdc_territory2') }} as territory
        on h.base_territory_id = territory.parent_territory_2_id
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

final_territory_hierarchy as (
    select
        --'parent_relationship' as hierarchy_type,
        h.base_territory_id,
        base_territory.developer_name as base_developer_name,
        h.parent_territory_id,
        hierarchy_territory.developer_name as hierarchy_developer_name,
        h.level,
        inherited_child_territory,
        array_agg(distinct sfdc_users.email) as dynatrace_user_emails_array

    from territory_hierarchy_parents as h
    inner join {{ ref('cur_sfdc_territory2') }} as base_territory
        on h.base_territory_id = base_territory.territory_2_id

    left join {{ ref('cur_sfdc_territory2') }} as hierarchy_territory --may not have a parent or child if it's first or last level
        on h.parent_territory_id = hierarchy_territory.territory_2_id

    -- left join prod_db.curated_salesforce.cur_sfdc_objectterritory2association object_territory
    --    on object_territory.territory_2_id = h.parent_territory_id

    left join {{ ref('cur_sfdc_userterritory2association') }} as user_territory
        on h.parent_territory_id = user_territory.territory_2_id

    left join dynatrace_users as sfdc_users
        on user_territory.user_id = sfdc_users.user_id

    group by all
)

select *
from final_territory_hierarchy
