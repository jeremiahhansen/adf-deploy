# adfdeploy
A lightweight Azure Data Factory (ADF) deployment process written in PowerShell Core. This script is inteded primarily to be used in release automation (CI/CD) pipelines. See the [Background](#background) section for more context.

## Table of Contents
1. [Usage](#usage)
   1. [Overview](#overview)
   1. [Execution Modes](#execution-modes)
   1. [Parameters](#parameters)
1. [ADF Objects Folder](#adf-objects-folder)
1. [Background](#background)
   1. [Context](#context)
   1. [ADF Automation Options](#adf-automation-options)
1. [Prerequisites](#Prerequisites)
1. [Legal](#legal)


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

In the Manual Azure Login mode the script executes the `Connect-AzAccount` CmdLet and interactively prompts the user to login. This is the default mode of the script and will be triggered when only the required parameters have been passed.

In the Automated Azure Login mode the script executes the `Connect-AzAccount -ServicePrincipal ...` CmdLet to login using the supplied Azure Active Directory App Registration (service account) credentials. Use this mode when calling this script from your DevOps pipeline.  This mode is triggered by passing the `serviceAccountDeployAppId` parameter to the sript and setting the `ADF_DEPLOY_APP_REGISTRATION_SECRET` environment variable.

### Parameters
Here is the list of supported parameters to the script. The last two *optional* parameters are used to control which [execution mode](#execution-modes) the script runs under. 

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

## Background
### Context
This script provides an alternative to Microsoft's suggested ADF CI/CD approach outlined in [Continuous integration and delivery in Azure Data Factory](https://docs.microsoft.com/en-us/azure/data-factory/continuous-integration-deployment). In my opinion Microsoft's approach has two significant drawbacks:

1. The approach is a bit convoluted involving two separate code structures and development lifecycle processes. For part of the process it uses individual files in regular project branches and then switches to using a single ARM templates in a dedicated `adf_publish` branch.
1. The use of the `adf_publish` branch is artifical and breaks with source control best practices. The code folder structure should be the same between branches of the same project.

That said deploying ADF objects is difficult and there is currently no easy answer. The following section outlines the possible approaches.

### ADF Automation Options
There are 3 primary options for automating the management and deployment of ADF objects:

1. Individual Object Files
   1. The most natural approach, what you'd expect to manage in code and through the development lifecycle
   1. Deployment is more complicated due to dependencies and triggers
   1. Only the PowerShell Az CmdLets let you create objects from individual JSON templates!
1. Single ARM Template
   1. Microsoft’s suggested approach
   1. The adf_publish branch is artificial and doesn't follow source control best practices
   1. Pretty good about adding parameters for hard-coded values
   1. ARM templates are super easy to deploy, can use any access method
1. Pure Code
   1. Creating pipelines and relationships between objects in code is a pain
   1. Very complicated due to dependencies
   1. Can use SDK in programming language of choice to accomplish (python, .NET, Java, JavaScript)
   1. How do you make this metadata driven? Need another layer like what JSON templates already provide

This script implements Option #1 Individual Object Files.


## Prerequisites
In order to run this script you must have the following:

1. An Azure account and subscription
1. An Azure Data Factory (ADF) resource created in your Azure subscription
1. An Azure Active Directory App Registration created with at least `Data Factory Contributor` role access
1. [PowerShell Core](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell) installed on your computer or build agent
1. The [Azure PowerShell Core Az Module](https://docs.microsoft.com/en-us/powershell/azure/new-azureps-module-az) installed on your computer or build agent


## Legal
Licensed under the Apache License, Version 2.0 (the "License"); you may not use this script except in compliance with the License. You may obtain a copy of the License at: [http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
