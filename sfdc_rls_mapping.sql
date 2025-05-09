/* https://docs.snowflake.com/en/user-guide/queries-hierarchical */


/* every owner or AE team member of an account */
/* bringing in as a test, the parent account and all children, but will need to recursively go through this */
/* Accounts they own or on the account sales team */
select 
    sfdc_account.account_id
    ,sfdc_account.name as account_name
    ,sfdc_account.parentid as parent_id
    ,sfdc_account.ownerid as account_owner_id
    ,sfdc_owner.email as owner_email
    ,sfdc_teammember.email as teammember_email
    
from prod_db.curated_salesforce.cur_sfdc_account sfdc_account
left join prod_db.base_salesforce.base_accountteammember account_team
    on account_team.accountid = sfdc_account.account_id
    and account_team.teammemberrole = 'Account Exec' /* testing for AE only */
left join prod_db.curated_salesforce.cur_sfdc_user sfdc_owner /*grabbing the user info of the owner of the account object */
    on sfdc_owner.user_id = sfdc_account.ownerid
left join prod_db.curated_salesforce.cur_sfdc_user sfdc_teammember /*grabbing the user info of the team member(s) on the account teammember object */
    on sfdc_teammember.user_id = account_team.userid
    
where sfdc_account.account_id IN ('')
    or sfdc_account.parentid IN ('')
order by sfdc_account.parentid desc
; 

/* Every owner, or opp team member assigned to an opportunity, rolled up to map them to the associated account */
/* All accounts they are assigned as opportunity owner or sales team member of where the opportunity under current fiscal year close date */
with current_fy as 
    (
    select dim_date.fulldate, dim_date.fy_enddate
    from prod_db.mart_global.dim_date
    where CURRENT_DATE() between fy_startdate and fy_enddate
    )
    
select distinct 
    sfdc_opp.accountid as account_id
    ,sfdc_opp.ownerid as opp_owner_id
    ,opp_owner_user.email as opp_owner_email
    ,oppteam.userid as oppteam_user_id
    ,opp_teammember_user.email as oppteam_email
    
    
from prod_db.curated_salesforce.cur_sfdc_opportunity sfdc_opp
inner join current_fy
    on current_fy.fulldate = sfdc_opp.closedate /* this will filter only on opps closed within the current fiscal year */
left join prod_db.base_salesforce.base_opportunityteammember oppteam
    on oppteam.opportunityid = sfdc_opp.opportunity_id
    
left join prod_db.curated_salesforce.cur_sfdc_user opp_owner_user /*grabbing the user info of the owner of the opp object */
    on opp_owner_user.user_id = sfdc_opp.ownerid
    
left join prod_db.curated_salesforce.cur_sfdc_user opp_teammember_user /*grabbing the user info of the team member(s) on the opp teammember object */
    on opp_teammember_user.user_id = oppteam.userid
  
limit 50
;
