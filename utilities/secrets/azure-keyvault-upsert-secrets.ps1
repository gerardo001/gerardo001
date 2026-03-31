[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$VaultName,

    [Parameter(Mandatory = $true)]
    [string]$SecretsFile,

    [string]$SubscriptionId,

    [switch]$PassThru
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Assert-AzCli {
    $azCommand = Get-Command az -ErrorAction SilentlyContinue
    if (-not $azCommand) {
        throw "Azure CLI (az) is not installed or not available in PATH."
    }

    try {
        az account show --only-show-errors --output none | Out-Null
    }
    catch {
        throw "No active Azure CLI login session. Run 'az login' first."
    }
}

function ConvertTo-SecretList {
    param(
        [Parameter(Mandatory = $true)]
        [object]$InputObject
    )

    if ($InputObject -is [System.Collections.IDictionary]) {
        $list = @()
        foreach ($key in $InputObject.Keys) {
            $list += [PSCustomObject]@{
                name  = [string]$key
                value = $InputObject[$key]
            }
        }
        return $list
    }

    if ($InputObject -is [System.Collections.IEnumerable] -and -not ($InputObject -is [string])) {
        $list = @()
        foreach ($item in $InputObject) {
            if ($null -eq $item.name -or $null -eq $item.value) {
                throw "Array format must contain objects with 'name' and 'value' properties."
            }
            $list += [PSCustomObject]@{
                name  = [string]$item.name
                value = $item.value
            }
        }
        return $list
    }

    throw "Unsupported JSON format. Use an object map or an array of { name, value } objects."
}

function ConvertTo-SecretValue {
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return ""
    }

    if ($Value -is [string]) {
        return $Value
    }

    if ($Value -is [bool] -or $Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) {
        return [string]$Value
    }

    return ($Value | ConvertTo-Json -Compress -Depth 20)
}

Assert-AzCli

if (-not (Test-Path -Path $SecretsFile -PathType Leaf)) {
    throw "Secrets file not found: $SecretsFile"
}

if ($SubscriptionId) {
    az account set --subscription $SubscriptionId --only-show-errors
}

# Validate vault access early so failures happen before we process secrets.
az keyvault show --name $VaultName --query id --output tsv --only-show-errors | Out-Null

$rawJson = Get-Content -Path $SecretsFile -Raw
if ([string]::IsNullOrWhiteSpace($rawJson)) {
    throw "Secrets file is empty: $SecretsFile"
}

$inputObject = $rawJson | ConvertFrom-Json -Depth 20
$secrets = ConvertTo-SecretList -InputObject $inputObject

if ($secrets.Count -eq 0) {
    Write-Warning "No secrets found in file: $SecretsFile"
    return
}

$results = @()
foreach ($secret in $secrets) {
    if ([string]::IsNullOrWhiteSpace($secret.name)) {
        throw "Secret name cannot be empty."
    }

    $secretValue = ConvertTo-SecretValue -Value $secret.value

    $exists = $false
    try {
        az keyvault secret show --vault-name $VaultName --name $secret.name --only-show-errors --output none | Out-Null
        $exists = $true
    }
    catch {
        $exists = $false
    }

    $action = if ($exists) { "updated" } else { "created" }
    az keyvault secret set --vault-name $VaultName --name $secret.name --value $secretValue --only-show-errors --output none | Out-Null

    $result = [PSCustomObject]@{
        Name   = $secret.name
        Action = $action
    }

    $results += $result
    Write-Host ("{0}: {1}" -f $result.Action, $result.Name)
}

Write-Host ("Processed {0} secrets in vault '{1}'." -f $results.Count, $VaultName)

if ($PassThru) {
    $results
}
