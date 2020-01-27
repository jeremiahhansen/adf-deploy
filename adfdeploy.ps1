<#
.SYNOPSIS
Deploy Azure Data Factory (ADF) objects

.DESCRIPTION
This script deploys Azure Data Factory (ADF) objects.

Important: When using a service account (app registration) the password must be set
in an environment variable named ADF_DEPLOY_APP_REGISTRATION_SECRET.

Script Assupmtions:
	1) The data factory already exists

.PARAMETER tenantId
The tenant to run the deployment against

.PARAMETER subscriptionId
The subscription to run the deployment against

.PARAMETER resourceGroupName
The resource group that containts the data factory

.PARAMETER resourceNamePrefix
The resource name prefix

.PARAMETER projectRoot
The path to the project root folder

.PARAMETER serviceAccountDeployAppId
Optional. The service principal application ID used to perform the deployment
#>

param
(
	[Parameter(Mandatory=$True)] [string]$tenantId,
	[Parameter(Mandatory=$True)] [string]$subscriptionId,
	[Parameter(Mandatory=$True)] [string]$resourceGroupName,
	[Parameter(Mandatory=$True)] [string]$resourceNamePrefix,
	[Parameter(Mandatory=$True)] [string]$projectRoot,
	[Parameter(Mandatory=$False)] [string]$serviceAccountDeployAppId
)


#---------------------------------------------------------------------------
# Step 1: Define the functions that we'll use
#---------------------------------------------------------------------------

# Azure PowerShell has the ability to persist credentials/context across
# sessions. It stores that context in the $env:USERPROFILE\.Azure directory.
# So even the first execution of this for a new session might reuse a previous
# context.  TODO: This should probably be updated with more context smarts.
# https://docs.microsoft.com/en-us/powershell/azure/context-persistence?view=azps-1.2.0
Function AzureLogin
{
	Param(
		[string]$tenantId,
		[string]$subscriptionId,
		[string]$serviceAccountDeployAppId,
		[string]$serviceAccountDeployKey
	)

	# Turn off autosaving Azure credentials
	Disable-AzContextAutosave;

	$needLogin = $true;

	$azureContext = Get-AzContext;
	if ($azureContext)
	{
		if (-not ([string]::IsNullOrEmpty($azureContext.Account)))
		{
			Write-Host "Login not needed, already logged in with $($azureContext.Account)";
			$needLogin = $false;
		}
	}

	if ($needLogin)
	{
		if ($serviceAccountDeployAppId)
		{
			Write-Host "Logging in with service account $serviceAccountDeployAppId";
	
			# TODO: Make the parameter a secure string and convert it before hand
			$serviceAccountDeployKeySecure = ConvertTo-SecureString $serviceAccountDeployKey -AsPlainText -Force;
	
			$serviceAccountDeployCred = New-Object -TypeName System.Management.Automation.PSCredential –ArgumentList $serviceAccountDeployAppId, $serviceAccountDeployKeySecure;
			Connect-AzAccount -ServicePrincipal -Credential $serviceAccountDeployCred –TenantId $tenantId;
		}
		else
		{
			Write-Host "Logging in manually";
	
			Connect-AzAccount;
		}
	
		# Set the Subscription ID to the desired Subscription
		Set-AzContext -SubscriptionId $subscriptionId;
	}
}

Function CreateDataFactoryObject
{
	Param(
		[hashtable]$createdObjects,
		[string]$resourceGroupName,
		[string]$dataFactoryName,
		[string]$objectType,
		[string]$objectName,
		[string]$objectDefinitionFile
	)

    # Skip objects we've already created
	if ($createdObjects[$objectName])
	{
		continue;
	}

	Write-Host "Creating data factory ${objectType} $objectName";
	switch ($objectType)
	{
		"pipeline" {
			Set-AzDataFactoryV2Pipeline `
				-ResourceGroupName $resourceGroupName `
				-DataFactoryName $dataFactoryName `
				-Name $objectName `
				-DefinitionFile $objectDefinitionFile `
				-Force;
		}
		"dataset" {
			Set-AzDataFactoryV2Dataset `
				-ResourceGroupName $resourceGroupName `
				-DataFactoryName $dataFactoryName `
				-Name $objectName `
				-DefinitionFile $objectDefinitionFile `
				-Force;
		}
		"linkedService" {
			Set-AzDataFactoryV2LinkedService `
				-ResourceGroupName $resourceGroupName `
				-DataFactoryName $dataFactoryName `
				-Name $objectName `
				-DefinitionFile $objectDefinitionFile `
				-Force;
		}
		"trigger" {
			Set-AzDataFactoryV2Trigger `
				-ResourceGroupName $resourceGroupName `
				-DataFactoryName $dataFactoryName `
				-Name $objectName `
				-DefinitionFile $objectDefinitionFile `
				-Force;
		}
	}

	$createdObjects.add($objectName, $objectDefinitionFile);
}

# Clean up ugly JSON indentation created by ConvertTo-Json
# Adapted from: https://github.com/PowerShell/PowerShell/issues/2736
Function FormatJson
{
	Param(
		[Parameter(Mandatory=$True, ValueFromPipeline=$True)]
		[String]$json,

		[Parameter(Mandatory=$True)]
		[string]$Separator
	)
	$indent = 0;
	($json -Split "`n" |
		ForEach-Object {
			# Decrease the indent if this line contains an ] or } (ignoring a line with [])
			if (($_ -match '[\}\]]') -and ($_ -notmatch '\[\]')) {
				$indent--;
			}
			$line = ($Separator * $indent) + $_.TrimStart().Replace(':  ', ': ');
			# Increase the indent if this line contains an [ or { (ignoring a line with [])
			if (($_ -match '[\{\[]') -and ($_ -notmatch '\[\]')) {
				$indent++;
			}
			$line;
		}
	) -Join "`n";
}

Function UpdateAdfLinkedServiceFile
{
	Param(
		[string]$linkedServiceFile,
		[string]$jsonAttributeName,
		[string]$jsonAttributeValue
	)

	$fileContents = (Get-Content $linkedServiceFile) | ConvertFrom-Json;
	$fileContents.properties.typeProperties.$jsonAttributeName = $jsonAttributeValue;
	$outputString = $fileContents | ConvertTo-Json -Depth 20 | FormatJson -Separator "`t";
	[System.IO.File]::WriteAllText($linkedServiceFile, $outputString);
}


#---------------------------------------------------------------------------
# Step 2: Define the variables that we'll use
#---------------------------------------------------------------------------

$serviceAccountDeployKey = [Environment]::GetEnvironmentVariable("ADF_DEPLOY_APP_REGISTRATION_SECRET");

$keyVaultName = "$($resourceNamePrefix)kv";
$dataFactoryName = "$($resourceNamePrefix)adf";
$functionAppName = "$($resourceNamePrefix)fa";

$objectFolder = "$projectRoot/adf-objects";
$createdObjects = @{};


#---------------------------------------------------------------------------
# Step 3: Login and validation
#---------------------------------------------------------------------------

# If logging in with a service account make sure the caller set the environment variable
if (($serviceAccountDeployAppId.Length -gt 0) -and ($serviceAccountDeployKey.Length -eq 0))
{
	Write-Host "ERROR: To login with a service account you must set the ADF_DEPLOY_APP_REGISTRATION_SECRET environment variable with the secret.";
	throw;
}

# Login
AzureLogin -tenantId $tenantId -subscriptionId $subscriptionId -serviceAccountDeployAppId $serviceAccountDeployAppId -serviceAccountDeployKey $serviceAccountDeployKey;

# Validate that the data factory exists
$dataFactory = Get-AzDataFactoryV2 -ResourceGroupName $resourceGroupName -Name $dataFactoryName;
if (!$dataFactory)
{
	Write-Host "ERROR: Data Factory $($dataFactoryName) does not exist.";
	throw;
}


#---------------------------------------------------------------------------
# Step 4: Replace any hard coded values in the ADF files
#---------------------------------------------------------------------------

UpdateAdfLinkedServiceFile -linkedServiceFile "${objectFolder}/linkedService/KeyVault_LS.json" -jsonAttributeName "baseUrl" -jsonAttributeValue "https://$($keyVaultName).vault.azure.net";
UpdateAdfLinkedServiceFile -linkedServiceFile "${objectFolder}/linkedService/FunctionApp_LS.json" -jsonAttributeName "functionAppUrl" -jsonAttributeValue "https://$($functionAppName).azurewebsites.net";


#---------------------------------------------------------------------------
# Step 5: Create the ADF linked services
#---------------------------------------------------------------------------

# Find all linked service definitions
$linkedServices = Get-ChildItem -Path ("${objectFolder}/linkedService/") -Recurse -Include *.json;

# Second, create those linked services that have no dependency on any other linked services
foreach ($linkedService in $linkedServices)
{
	$jsonFileObject = (Get-Content $linkedService) -join "`n" | ConvertFrom-Json;

#	if ($jsonFileObject.properties.typeProperties.linkedServiceName)
	if (Get-Content $linkedService | Select-String -Pattern "LinkedServiceReference")
	{
		continue;
	}
	else
	{
		CreateDataFactoryObject $createdObjects $resourceGroupName $dataFactoryName "linkedService" $jsonFileObject.name $linkedService;
	}
}

# Third, create any remaining linked services
foreach ($linkedService in $linkedServices)
{
	$jsonFileObject = (Get-Content $linkedService) -join "`n" | ConvertFrom-Json;
	CreateDataFactoryObject $createdObjects $resourceGroupName $dataFactoryName "linkedService" $jsonFileObject.name $linkedService;
}


#---------------------------------------------------------------------------
# Step 6: Create the ADF datasets
#---------------------------------------------------------------------------

# Find all dataset definitions
$datasets = Get-ChildItem -Path ("${objectFolder}/dataset/") -Recurse -Include *.json;

foreach ($dataset in $datasets)
{
	$jsonFileObject = (Get-Content $dataset) -join "`n" | ConvertFrom-Json;
	CreateDataFactoryObject $createdObjects $resourceGroupName $dataFactoryName "dataset" $jsonFileObject.name $dataset;
}


#---------------------------------------------------------------------------
# Step 7: Create the ADF pipelines
#---------------------------------------------------------------------------

# Find all pipeline definitions
$pipelines = Get-ChildItem -Path ("${objectFolder}/pipeline/")  -Recurse -Include *.json;

# First, create all non-control pipelines
foreach ($pipeline in $pipelines)
{
	if ($pipeline.name.Trim().ToLowerInvariant().Contains('_control_'))
	{
		continue;
	}

	$jsonFileObject = (Get-Content $pipeline) -join "`n" | ConvertFrom-Json;
	CreateDataFactoryObject $createdObjects $resourceGroupName $dataFactoryName "pipeline" $jsonFileObject.name $pipeline;
}

# Second, create the control pipelines
foreach ($pipeline in $pipelines)
{
	$jsonFileObject = (Get-Content $pipeline) -join "`n" | ConvertFrom-Json;
	CreateDataFactoryObject $createdObjects $resourceGroupName $dataFactoryName "pipeline" $jsonFileObject.name $pipeline;
}


#---------------------------------------------------------------------------
# Step 8: Create the ADF triggers
#---------------------------------------------------------------------------

# Find all trigger definitions
$triggers = Get-ChildItem -Path ("${objectFolder}/trigger/") -Recurse -Include *.json -ErrorAction SilentlyContinue;

# First, disable any that are currently running
$deployedTriggers = Get-AzDataFactoryV2Trigger -ResourceGroupName $resourceGroupName -DataFactoryName $dataFactoryName;
foreach ($trigger in $deployedTriggers)
{
	if ($trigger.properties.runtimeState -eq "Started")
	{
		Write-Host "Stopping trigger $($trigger.name)";
		Stop-AzDataFactoryV2Trigger -ResourceGroupName $resourceGroupName -DataFactoryName $dataFactoryName -Name $trigger.name -Force;
	}
}

# Second, create the triggers and keep track of ones that need to be started
$triggersToStart = @();
foreach ($trigger in $triggers)
{
	$jsonFileObject = (Get-Content $trigger) -join "`n" | ConvertFrom-Json;
	CreateDataFactoryObject $createdObjects $resourceGroupName $dataFactoryName "trigger" $jsonFileObject.name $trigger;

	if ($jsonFileObject.properties.runtimeState -eq "Started")
	{
		$triggersToStart += $jsonFileObject.name;
	}
}

# Third, start the triggers
$triggerWaitTimeSeconds = 60;
if ($triggersToStart.Count -gt 0)
{
	# Sleep for a few minutes to allow the triggers to be provisioned
	Write-Host "Waiting ${triggerWaitTimeSeconds} seconds for triggers to be provisioned";
	Start-Sleep -Seconds $triggerWaitTimeSeconds;

	# Then start each one, pausing briefly between each
	foreach ($triggerName in $triggersToStart)
	{
		Write-Host "Starting trigger ${triggerName}";
		Start-AzDataFactoryV2Trigger -ResourceGroupName $resourceGroupName -DataFactoryName $dataFactoryName -Name $triggerName -Force;

		Start-Sleep -Seconds 10;
	}
}
