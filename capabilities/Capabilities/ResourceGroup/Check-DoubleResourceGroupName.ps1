<#
	.SYNOPSIS
	Get all Resource Groups from all versions
	
	.PARAMETER RootFolder
	This should point to the root directory where the version directories of the resource groups can be found
	i.e: /ResourceGroups/ResourceGroups/

	.DESCRIPTION
	Get all the resource group names of all versions by calling Get-ResourceGroupNames.ps1 in every v* subdirectory
	
	.OUTPUTS
#>

####################### NOTE ####################
#  This script uses $PSScriptRoot, which means  #
#  You cannot copy/paste this script in PS ISE  #
#  Since $PSScriptRoot will not be filled there #
#                                               #
# Just execute this script from ISE             #
#################################################
[CmdletBinding()]
Param(
	[parameter(Mandatory=$true)]
	[ValidateScript({Test-Path $_})]
	[string]$RootFolder
)


function Get-AllResourceGroups {
	$ResourceGroupNames = @{}
	Foreach ($VersionDir in $(Get-ChildItem -Directory -Filter "v*" $PSScriptRoot  | Where-Object { $_.BaseName -match "^v[0-9]+\.[0-9]+\.[0-9]+$"})) {
		if (Test-Path "$PSScriptRoot\$VersionDir\Get-ResourceGroupNames.ps1") {
            # Execute version based powershell command to retrieve all resource groups defined in $RootFolder\$VersionDir, this should be a compatible version with the script.
            # This script must always return the same kind of hash table:
            # $result[$RG]['file'] = "MyFileName.json"
            # $result[$RG]['subscription'] = "Non Prod, P01, *"  - Note '*' is every subscription
            # For all versions it will be placed in one array
			$VersionResourceGroups = Invoke-Expression "& `"$PSScriptRoot\$VersionDir\Get-ResourceGroupNames.ps1`" -RootFolder `"$RootFolder\$VersionDir`""
			ForEach($RG in $($VersionResourceGroups.Keys)) {
				if ($ResourceGroupNames.Keys -notcontains $RG) {
					$ResourceGroupNames[$RG] = $VersionResourceGroups[$RG]
				} else {
					$ResourceGroupNames[$RG]['file'] += $VersionResourceGroups[$RG]['file']
					$ResourceGroupNames[$RG]['subscription'] += $VersionResourceGroups[$RG]['subscription']
				}
			}
		} else {
			Throw "Cannot find Get-ResourceGroupNames.ps1 script in version dir $VersionDir"
		}
        
	}
	return $ResourceGroupNames
}

function Check-DoubleResourceGroups ($ResourceGroups) {
	$result = $false
	Foreach ($ResourceGroup in $ResourceGroups.Keys) {
		Write-Host "Resource Group: $ResourceGroup"
		Foreach ($Subscription in $ResourceGroups[$ResourceGroup]['subscription']) {
			Write-Host "  Subscription: $Subscription"
			if (($ResourceGroups[$ResourceGroup]['subscription'] | Where-Object { $_ -eq $Subscription }).Count -gt 1) {
				Write-Warning "    Subscription is double"
				$result = $true
			}
		}
		Foreach ($FileName in $ResourceGroups[$ResourceGroup]['file']) {
			Write-Host "  File: $FileName"
		}
		if ($ResourceGroups[$ResourceGroup]['subscription'] -contains "*" `
			-and $ResourceGroups[$ResourceGroup]['subscription'].Count -gt 1) {
				Write-Warning "Resource group is multiple times defined for the same subscription"
				$result = $true
		}
		Write-Host
	}
	return $result
}



$AllResourceGroups = Get-AllResourceGroups

if ((Check-DoubleResourceGroups -ResourceGroups $AllResourceGroups) -eq $true) {
	Throw "One or more resource groups are defined multiple times"
}