# Github Actions: OpsGenie

This Github action can be used to generate alert to OpsGenie by generating a CURL request to the OpsGenie API.

#### Required Parameters

* ALIAS
         
  User defined identifier for the alert (this is used by OpsGenie to de-duplicate alerts)

* MESSAGE       

  The content of the alert message

* PRIORITY      

  The priority level of the alert (one of the pre-defined OpsGenie levels: P1, P2, P3, P4, P5)
  
* API_KEY

  The OpsGenie API key (this will need to be pre-configured via the OpsGenie website)

#### Optional Parameters

* USE_EU_INSTANCE

  Use the EU instance of OpsGenie

* RESPONDERS

  The list of responders the alert is targeted to (comma-separated, format: id:UUID:type OR name:TeamName:type OR username:Email:type)

* TAGS

  The comma separated list of tags to be attached to the alert
    
#### Example Usage

The following example shows how the action can be used in a Github workflow file. This sends a P5 notification on start
of deployment, and then generates another P5 notification on successful deployment- or a P1 alert on failure

```yaml
name: Deploy Production Environment

on:
  push:
    branches:
      - master

jobs:
  deploy-production-start:
    name: Start Notification
    runs-on: ubuntu-latest
    steps:
      - name: Send OpsGenie Alert
        uses: dil-zsmolnar/actions-opsgenie@master
        with:
          API_KEY: ${{ secrets.OPSGENIE_API_KEY }}
          PRIORITY: 'P5'
          ALIAS: 'deploy-production'
          MESSAGE: 'Deployment to production started'
          TAGS: pipeline,ci
          RESPONDERS: id:0a50a357-09c1-4ae4-9f0b-bb3e1ad6d8b5:team,username:support@acme.com:user,name:NOC:team

  deploy-production:
    name: Deploy (Production)
    runs-on: ubuntu-latest
    steps:
      ...
      Deployment logic here
      ...

  deploy-production-success:
    name: Success Notification
    needs: deploy-production
    if: success()
    runs-on: ubuntu-latest
    steps:
      - name: Send OpsGenie Alert
        uses: dil-zsmolnar/actions-opsgenie@master
        with:
          API_KEY: ${{ secrets.OPSGENIE_API_KEY }}
          PRIORITY: 'P5'
          ALIAS: 'deploy-production'
          MESSAGE: 'Deployment to production completed successfully'
          RESPONDERS: id:0a50a357-09c1-4ae4-9f0b-bb3e1ad6d8b5:team

  deploy-production-failed:
    name: Failed Notification
    needs: deploy-production
    if: failure()
    runs-on: ubuntu-latest
    steps:
      - name: Send OpsGenie Alert
        uses: dil-zsmolnar/actions-opsgenie@master
        with:
          API_KEY: ${{ secrets.OPSGENIE_API_KEY }}
          PRIORITY: 'P1'
          ALIAS: 'deploy-production-failed'
          MESSAGE: 'Deployment to production failed. please review Github Actions logs'
          TAGS: pipeline,ci
          RESPONDERS: id:0a50a357-09c1-4ae4-9f0b-bb3e1ad6d8b5:team,username:support@acme.com:user,name:NOC:team
```
