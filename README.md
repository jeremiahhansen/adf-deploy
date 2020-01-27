# adfdeploy
A lightweight Azure Data Factory (ADF) deployment process written in PowerShell Core.

## Usage
### Overview
adfdeploy is a lightweight PowerShell Core script used to deploy ADF objects. See the [Prerequisites](#prerequisites) section for the required setup steps. Once the prerequisites have been met the script can be invoked as follows:
```
pwsh -File adfdeploy.ps1 -tenantId "<value>" -subscriptionId "<value>" -resourceGroupName "<value>" -resourceNamePrefix "<value>" -projectRoot "<value>"
```
See the [Parameters](#parameters) section below for a detailed description of the possible parameters.

### Execution Modes
This script can be run in two different modes:
1. Manual Azure Login
1. Automated Azure Login

In the Manual Azure Login mode the script executes the `Connect-AzAccount` CmdLet and interactively prompts the user to login. This is the default mode of the script and will be triggered when called with only the required parameters have been passed.

In the Automated Azure Login mode the script executes the `Connect-AzAccount -ServicePrincipal ...` CmdLet to login using the supplied Azure Active Directory App Registration (service account) credentials. Use this mode when calling this scripts from your DevOps pipeline.  This mode is triggered by passing the `serviceAccountDeployAppId` parameter to the sript and setting the `ADF_DEPLOY_APP_REGISTRATION_SECRET` environment variable.

### Parameters
Here is the list of support parameters to the script. The last two *optional* parameters are used to control which [execution mode](#execution-modes) the script runs under. 

Parameter | Type | Description
--- | --- | ---
tenantId | PowerShell | The tenant to run the deployment against
subscriptionId | PowerShell | The subscription to run the deployment against
resourceGroupName | PowerShell | The resource group that containts the data factory
resourceNamePrefix | PowerShell | The resource name prefix
projectRoot | PowerShell | The path to the project root folder which contains the `adf-objects` folder
serviceAccountDeployAppId | PowerShell | *(Optional)* The service principal application ID used to perform the deployment
ADF_DEPLOY_APP_REGISTRATION_SECRET | Environment Variable | *(Optional)* The service principal application secret, required when serviceAccountDeployAppId is supplied

**Please Note:** The `ADF_DEPLOY_APP_REGISTRATION_SECRET` parameter is passed through an environment variable, not a regular PowerShell parameter. The reason for this is that this script is intended primarily to be used in release automation (CI/CD) scenarios. When running on a hosted build agent the recommended method for passing sensitive information is through environment variables, not command line arguments (which can get logged).

## ADF Objects Folder
This script assumes that the ADF objects can be found in the `/adf-objects` folder within the `projectRoot` folder (specified as a parameter to the script). The `/adf-objects` folder should have the following structure (as managed by ADF in Git Repository mode):

```
(projectRoot)
|
|-> adf-objects
    |-> dataset
    |   |-> dataset1.json
    |-> linkedService
    |   |-> linkedService1.json
    |-> pipeline
    |   |-> pipeline1.json
    |-> trigger
    |   |-> trigger.json
```

## Prerequisites
This script depends on the Azure PowerShell Az CmdLets.

## Legal
Licensed under the Apache License, Version 2.0 (the "License"); you may not use this script except in compliance with the License. You may obtain a copy of the License at: [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
