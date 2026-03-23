{{
    config(
        materialized = 'table'
    )
}}

with

accountshare_components as (

    select
        sfdc_account_id,
        dynatrace_user_email,
        'user' as sharing_rule_group
    from {{ ref('int_sfdc_accountshare_user') }}
    where dynatrace_user_email is not null

    union all

    select
        sfdc_account_id,
        dynatrace_user_email,
        'role' as sharing_rule_group
    from {{ ref('int_sfdc_accountshare_group_role') }}
    where dynatrace_user_email is not null

    union all

    select
        sfdc_account_id,
        dynatrace_user_emails as dynatrace_user_email,
        'territory' as sharing_rule_group
    from {{ ref('int_sfdc_accountshare_group_territory') }}
    where dynatrace_user_emails is not null

    union all

    select
        sfdc_account_id,
        dynatrace_user_email,
        'queue' as sharing_rule_group
    from {{ ref('int_sfdc_accountshare_group_queue') }}
    where dynatrace_user_email is not null

    union all

    select
        sfdc_account_id,
        dynatrace_user_email,
        'regular' as sharing_rule_group
    from {{ ref('int_sfdc_accountshare_group_regular_with_recursion') }}
    where dynatrace_user_email is not null

    union all

    select
        sfdc_account_id,
        dynatrace_user_email,
        'role and subordinates' as sharing_rule_group
    from {{ ref('int_sfdc_accountshare_group_roleandsubordinates') }}
    where dynatrace_user_email is not null
),

active_users as (
    select
        *
    from accountshare_components 
    inner join  {{ ref('cur_sfdc_user') }} as sfdc_user
        on accountshare_components.dynatrace_user_email = sfdc_user.email
    where sfdc_user.termination_date is null

),

accountshare_components_unique as (
    select
        sfdc_account_id,
        dynatrace_user_email,
        array_unique_agg(sharing_rule_group) as sources
    from active_users 
    group by sfdc_account_id, dynatrace_user_email
),

accountshare_components_all as (
    select
        sfdc_account_id,
        dynatrace_user_email,
        sources,
        false as is_inherited,
        null as inherited_from_role
    from accountshare_components_unique

),


sfdc_account as (
    select
        sfdc_account.account_id as sfdc_account_id,
        sfdc_account.territory_label,
        sfdc_account.territory_type,
        sfdc_account.territory_geography,
        sfdc_account.territory_super_region,
        sfdc_account.territory_sales_region,
        trachier_parent_company,
        trachier_duns_global_ultimate_parent,
        trachier_excluded_from_account_hierarchies,
        trachier_primary_master_account
    from {{ ref('cur_sfdc_account') }} as sfdc_account
)

select distinct
    accountshare_components.sfdc_account_id,
    sfdc_account.territory_label,
    sfdc_account.territory_type,
    sfdc_account.territory_geography,
    sfdc_account.territory_super_region,
    sfdc_account.territory_sales_region,
    lower(accountshare_components.dynatrace_user_email) as dynatrace_user_email,
    accountshare_components.is_inherited,
    accountshare_components.inherited_from_role,
    accountshare_components.sources
from accountshare_components_all as accountshare_components
left join sfdc_account
    on accountshare_components.sfdc_account_id = sfdc_account.sfdc_account_id
where accountshare_components.dynatrace_user_email is not null
