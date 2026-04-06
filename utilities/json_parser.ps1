# https://copilot.microsoft.com/chats/jQGDu9i4tbSzMaeKcUdfR

function Print-JsonValues {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JsonFilePath
    )

    # Read and parse the JSON file
    $jsonContent = Get-Content $JsonFilePath -Raw | ConvertFrom-Json

    function Traverse-Json {
        param ($item)

        if ($item -is [System.Collections.IDictionary]) {
            foreach ($key in $item.Keys) {
                Traverse-Json $item[$key]
            }
        } elseif ($item -is [System.Collections.IEnumerable] -and !$item.GetType().IsPrimitive -and $item -ne $null) {
            foreach ($element in $item) {
                Traverse-Json $element
            }
        } else {
            Write-Output $item
        }
    }

    Traverse-Json $jsonContent
}

function Print-JsonValuesWithPath {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JsonFilePath
    )

    # Read and parse the JSON file
    $jsonContent = Get-Content $JsonFilePath -Raw | ConvertFrom-Json

    function Traverse-Json {
        param (
            $item,
            [string]$path = ""
        )

        if ($item -is [System.Collections.IDictionary]) {
            foreach ($key in $item.Keys) {
                $newPath = if ($path) { "$path.$key" } else { $key }
                Traverse-Json $item[$key] $newPath
            }
        } elseif ($item -is [System.Collections.IEnumerable] -and !$item.GetType().IsPrimitive -and $item -ne $null) {
            $index = 0
            foreach ($element in $item) {
                $newPath = "$path[$index]"
                Traverse-Json $element $newPath
                $index++
            }
        } else {
            Write-Output "$path = $item"
        }
    }

    Traverse-Json $jsonContent
}
# Example usage:   
function Print-JsonValuesWithPathToFile {
    param (
        [Parameter(Mandatory = $true)]
        [string]$JsonFilePath,

        [Parameter(Mandatory = $true)]
        [string]$OutputFilePath
    )

    # Read and parse the JSON file
    $jsonContent = Get-Content $JsonFilePath -Raw | ConvertFrom-Json

    # Create or clear the output file
    Clear-Content -Path $OutputFilePath -ErrorAction SilentlyContinue
    New-Item -Path $OutputFilePath -ItemType File -Force | Out-Null

    function Traverse-Json {
        param (
            $item,
            [string]$path = ""
        )

        if ($item -is [System.Collections.IDictionary]) {
            foreach ($key in $item.Keys) {
                $newPath = if ($path) { "$path.$key" } else { $key }
                Traverse-Json $item[$key] $newPath
            }
        } elseif ($item -is [System.Collections.IEnumerable] -and !$item.GetType().IsPrimitive -and $item -ne $null) {
            $index = 0
            foreach ($element in $item) {
                $newPath = "$path[$index]"
                Traverse-Json $element $newPath
                $index++
            }
        } else {
            "$path = $item" | Out-File -FilePath $OutputFilePath -Append
        }
    }

    Traverse-Json $jsonContent
}

function Update-JsonFromJsonFile{

    # Load the source JSON file (the one to be updated)
    $sourceJsonPath = "C:\Path\To\Source.json"
    $sourceJson = Get-Content -Path $sourceJsonPath | ConvertFrom-Json

    # Load the update JSON file (the one with new values)
    $updateJsonPath = "C:\Path\To\Update.json"
    $updateJson = Get-Content -Path $updateJsonPath | ConvertFrom-Json

    # Update the source JSON with values from the update JSON
    foreach ($key in $updateJson.PSObject.Properties.Name) {
        if ($sourceJson.PSObject.Properties.Name -contains $key) {
            $sourceJson.$key = $updateJson.$key
        }
    }
}

# Save the updated JSON back to the source file
# $sourceJson | ConvertTo-Json -Depth 10 | Set-Content -Path $sourceJsonPath
