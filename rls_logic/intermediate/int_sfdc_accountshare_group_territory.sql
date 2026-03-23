{{
    config(
        materialized = 'table'
    )
}}

with

accountshare as (

    select distinct
        accountshare.accountid as sfdc_account_id,
        sfdc_group.developer_name,
        territory2.territory_2_id
    from {{ ref('cur_sfdc_accountshare') }} as accountshare
    inner join {{ ref('cur_sfdc_group') }} as sfdc_group --confirmed all records are found in user table, no nulls
        on accountshare.userorgroup_id = sfdc_group.group_id
    inner join {{ ref('cur_sfdc_territory2') }} as territory2
        on sfdc_group.developer_name = territory2.developer_name
    inner join {{ ref('cur_sfdc_userterritory2association') }} as userterritory2association
        on territory2.territory_2_id = userterritory2association.territory_2_id
    where
        accountshare.userorgroup_id like '00G%' --groups only
        and sfdc_group.type = 'Territory'

),

recursion as (

    select
        base_developer_name,
        parent_territory_id,
        hierarchy_developer_name,
        dynatrace_user_emails_array
    from {{ ref('int_territory_hierarchy_recursion') }}
    where array_size(dynatrace_user_emails_array) > 0
    
),

hierarchy_territory as (

    select
        accountshare.sfdc_account_id,
        accountshare.developer_name,
        recursion.hierarchy_developer_name,
        recursion.dynatrace_user_emails_array
    from accountshare
    inner join recursion
        on accountshare.developer_name = recursion.base_developer_name -- grabs all parent roles

),

unique_records as (

    select distinct
        dynatrace_user_emails_array,
        sfdc_account_id
    from hierarchy_territory

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
