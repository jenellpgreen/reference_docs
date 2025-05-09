## Describe your changes
_Provide a description for the rationale/reason behind this change_


## JIRA ticket number and link
_Provide a link to the associated JIRA ticket_


## Merge Impact
_Provide validation/regression queries and results for changes to help speed up approvals_

## Other Notes or Relevant Information for Reviewers
_List open questions and/or other details your reviewer(s) should know about_


## Checklist before requesting a review
_Place an X in the box to use markdown formatting to create a checkmark_
- [ ] I have performed a thorough self-review of my code
- [ ] I have successfully ran a `dbt compile` locally to ensure that no compilation errors exist
- [ ] I have successfully ran a `SQLFluff Lint` / `SQLFluff Fix` on any modified content and ensured that no errors exist.
  - Reference [this document](https://dt-rnd.atlassian.net/wiki/spaces/BSBIRD/pages/897587929/SQL+Style+Guide) for our SQL style guide and [this document](https://dt-rnd.atlassian.net/wiki/spaces/BSBIRD/pages/970360645/How+to+use+SQLFluff) for how to use SQLFluff
- [ ] All models, whether directly changed by this PR or not, run successfully via the following means:
    - [ ] I have successfully executed `dbt build -x -s {{ my_models+ }} --full-refresh` locally OR
    - [ ] I have successfully executed `dbt build -x -s {{ my_models+ }}` locally
- [ ] I have ensured that all models modified/created by this PR that are not materialized as a view have an appropriate refresh cadence dbt tag

## Future State Needs

- At minimum `unique` & `not_null` exist on any newly created models' unique keys
  - Custom tests should be created on models pertaining to critical business metrics or definitions (e.g. ARR should never be a negative, close dates should never be before open dates, etc.)
- Documentation exists in the following capacities for any newly created/modified content:
  - dbt yaml
  - Confluence
