{{
    config(
        materialized = 'table'
    )
}}

/*creating this model to do a listagg on the email for testing purposes only. Will combine with the original model once we decide on path forward */
select
    sfdc_account_id,
    territory_label,
    territory_type,
    territory_geography,
    territory_super_region,
    territory_sales_region,
    listagg(dynatrace_user_email, ',') as dynatrace_user_emails_listagg
from {{ ref('mart_accountshare_user_mapping') }}
group by
    sfdc_account_id,
    territory_label,
    territory_type,
    territory_geography,
    territory_super_region,
    territory_sales_region
