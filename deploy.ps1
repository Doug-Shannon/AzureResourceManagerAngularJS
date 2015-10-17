# Deployment settings
$hostingPlanName = "ArmAngularSampleHostingPlan"
$resourceGroupName = "ArmAngularSample"
$storageAccountName = "armangularsamplesa"
$location = "West Europe"
$siteName = "ArmAngularSampleWebsite"

# Configure Azure and the Powershell shell - select a subscription if you have multiple
# Select-AzureSubscription -SubscriptionId {{your-subscription-id}}
Switch-AzureMode AzureResourceManager

# Create Azure Resoure Group
New-AzureResourceGroup -Name $resourceGroupName -Location $location -Force

# Deploy storage
New-AzureResourceGroupDeployment -ResourceGroupName $resourceGroupName `
                                 -Name AzmSampleStorageDeployment `
								 -TemplateFile "storagedeploy.json" `
								 -appStorageAccountName $storageAccountName 				 
$storageAccountKey = (Get-AzureStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName).Key1

# Build deployment package
grunt build
cp .\website.publishproj .\dist\website.publishproj
C:\"Program Files (x86)"\MSBuild\14.0\bin\msbuild.exe .\dist\website.publishproj /T:Package /P:PackageLocation="." /P:_PackageTempDir="packagetmp"
$websitePackage = ".\dist\website.zip"

# Upload packages
$storageCtx = New-AzureStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageAccountKey
if (-Not (Get-AzureStorageContainer -Context $storageCtx | Where-Object { $_.Name -eq "packages" }) ) {
	New-AzureStorageContainer -Name "packages" -Context $storageCtx -Permission Blob
}
Set-AzureStorageBlobContent -File $websitePackage -Container "packages" -Blob website.zip -Context $storageCtx -Force
$uploadedPackage = "https://$storageAccountName.blob.core.windows.net/packages/website.zip"
$sasToken = New-AzureStorageContainerSASToken -Container "packages" -Context $storageCtx -Permission r
$sasToken = ConvertTo-SecureString $sasToken -AsPlainText -Force

# Deploy website
New-AzureResourceGroupDeployment -ResourceGroupName $resourceGroupName `
                                 -Name AnalyticsLiveServiceDeployment `
								 -TemplateFile "azuredeploy.json" `
								 -hostingPlanName $hostingPlanName `
								 -location $location `
								 -siteName $siteName `
								 -packageUrl $uploadedPackage `
								 -sasToken $sasToken
