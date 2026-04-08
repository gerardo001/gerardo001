# Function to log messages
function Write-Log {
    param([string]$Message, [string]$Level = “INFO”)
    $timestamp = Get-Date -Format “yyyy-MM-dd HH:mm:ss”
    $logMessage = “[$timestamp] [$Level] $Message”
    Write-Host $logMessage
    Add-Content -Path “prompts\analysis.log” -Value $logMessage

}

# Function to safely execute git commands
function Invoke-GitCommand {
    param([string]$Command, [string]$WorkingDirectory = $PWD)
    try {
        $originalLocation = Get-Location
        Set-Location $WorkingDirectory
        Write-Log “Executing: git $Command” “DEBUG”
        $result = Invoke-Expression “git $Command 2>&1”
        if ($LASTEXITCODE -ne 0) {
            Write-Log “Git command failed: $result” “ERROR”
            return $null
        }
        return $result
    }
    catch {
        Write-Log “Exception in git command: $($_.Exception.Message)” “ERROR”
        return $null
    }
    finally {
        Set-Location $originalLocation
    }

}

# Function to extract TargetFramework from csproj file
function Get-TargetFramework {
    param([string]$CsprojPath)
    try {
        if (-not (Test-Path $CsprojPath)) {
            return $null
        }
        [xml]$csproj = Get-Content $CsprojPath
        # Look for TargetFramework in PropertyGroup
        $targetFramework = $csproj.Project.PropertyGroup.TargetFramework
        if ($targetFramework) {
            return $targetFramework
        }
        # Look for TargetFrameworks (plural) in case of multi-targeting
        $targetFrameworks = $csproj.Project.PropertyGroup.TargetFrameworks
        if ($targetFrameworks) {
            return $targetFrameworks
        }
        return $null
    }
    catch {
        Write-Log “Error reading csproj file $CsprojPath`: $($_.Exception.Message)” “ERROR”
        return $null
    }

}

# Function to analyze .csproj files in a repository
function Analyze-CsprojFiles {
    param(
        [string]$RepoPath,
        [string]$RepoName
    )
    $results = @()
    # Find all .csproj files in the repository
    $csprojFiles = Get-ChildItem -Path $RepoPath -Recurse -Filter “*.csproj” -File -ErrorAction SilentlyContinue
    if ($csprojFiles.Count -eq 0) {
        Write-Log “No .csproj files found in repository: $RepoName” “WARNING”
        # Still add an entry to show the repo was processed
        $results += [PSCustomObject]@{
            Repository      = $RepoName
            CsprojPath      = “No .csproj files found”
            TargetFramework = “”
            Status          = “No csproj files”
        }
    }
    else {
        Write-Log “Found $($csprojFiles.Count) .csproj files in $RepoName”
        foreach ($csprojFile in $csprojFiles) {
            $relativePath = $csprojFile.FullName.Substring($RepoPath.Length + 1)
            $targetFramework = Get-TargetFramework $csprojFile.FullName
            if ($targetFramework) {
                Write-Log “Found TargetFramework ‘$targetFramework’ in $relativePath”
                $status = “Success”
            }
            else {
                Write-Log “No TargetFramework found in $relativePath” “WARNING”
                $status = “No TargetFramework found”
            }
            $results += [PSCustomObject]@{
                Repository      = $RepoName
                CsprojPath      = $relativePath
                TargetFramework = if ($targetFramework) { $targetFramework } else { “” }
                Status          = $status
            }
        }
    }
    return $results

}

# Function to process a single repository
function Process-Repository {
    param([string]$RepoName, [string]$RepoUrl)
    Write-Log “Processing repository: $RepoName”
    $repoPath = Join-Path $WorkDir $RepoName
    $results = @()
    try {
        # Create work directory if it doesn’t exist
        if (-not (Test-Path $WorkDir)) {
            New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
        }
        # Clean up existing repo directory if it exists
        if (Test-Path $repoPath) {
            Write-Log “Removing existing directory: $repoPath” “DEBUG”
            Remove-Item -Path $repoPath -Recurse -Force
        }
        # Clone the repository
        Write-Log “Cloning repository: $RepoUrl”
        $cloneResult = Invoke-GitCommand “clone `”$RepoUrl`” `”$repoPath`”” $WorkDir
        if ($null -eq $cloneResult) {
            Write-Log “Failed to clone repository: $RepoName” “ERROR”
            return $results
        }
        # Analyze .csproj files in the repository
        $results = Analyze-CsprojFiles -RepoPath $repoPath -RepoName $RepoName
        # Clean up the cloned repository to save space
        Write-Log “Cleaning up repository directory: $repoPath” “DEBUG”
        Remove-Item -Path $repoPath -Recurse -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-Log “Error processing repository $RepoName`: $($_.Exception.Message)” “ERROR”
        $results += [PSCustomObject]@{
            Repository      = $RepoName
            CsprojPath      = “ERROR”
            TargetFramework = “”
            Status          = “Error: $($_.Exception.Message)”
        }
    }
    return $results

}

function Update-TreatWarningsAsErrors-In-Csproj {
    param([string]$CsprojPath,
        [string]$PropertyName = “TreatWarningsAsErrors”,
        [bool]$SetToValue = $false)
    try {
        [xml]$csproj = Get-Content $CsprojPath
        # $propertyGroups = $csproj.Project.PropertyGroup
        $treatWarningsAsErrorsNode = $csproj.Project.PropertyGroup.TreatWarningsAsErrors
        $treatWarningsAsErrorsNode.Value = $SetToValue
        $updated = $true
        if ($updated) {
            $csproj.Save($CsprojPath)
            Write-Log “Updated TreatWarningsAsErrors in $CsprojPath”
        }
        else {
            Write-Log “TreatWarningsAsErrors already set to true in $CsprojPath”
        }
    }
    catch {
        Write-Log “Error updating csproj file $CsprojPath`: $($_.Exception.Message)” “ERROR”
    }

}

function Invoke-Repositories-List {
    # PowerShell script to analyze TargetFramework in repositories from repos_list.csv
    # Usage: .analyze-repos-targetframework.ps1
    param(
        [string]$CsvFile = “repos_list.csv”,
        [string]$OutputFile = “targetframework-analysis.csv”,
        [string]$WorkDir = “.temp-repos”,
        [string]$BaseUrl = “https://dev.azure.com/JM-FAMILY/SET-Apps/_git/”,
        [int]$MaxRepos = 0  # 0 means process all repos
    )
    # Import required modules
    if (Get-Module -ListAvailable -Name PowerShellGet) {
        Write-Host “PowerShell modules available” -ForegroundColor Green
    }
    else {
        Write-Warning “Required PowerShell modules may not be available”
    }
    # Main script execution
    Write-Log “Starting TargetFramework analysis script”
    Write-Log “CSV File: $CsvFile”
    Write-Log “Output File: $OutputFile”
    Write-Log “Work Directory: $WorkDir”
    # Check if CSV file exists
    if (-not (Test-Path $CsvFile)) {
        Write-Log “CSV file not found: $CsvFile” “ERROR”
        exit 1
    }
    # Read the repository list from CSV
    try {
        $repositories = Import-Csv $CsvFile
        Write-Log “Loaded $($repositories.Count) repositories from CSV”
    }
    catch {
        Write-Log “Error reading CSV file: $($_.Exception.Message)” “ERROR”
        exit 1
    }
    # Limit number of repos if MaxRepos is specified
    if ($MaxRepos -gt 0 -and $repositories.Count -gt $MaxRepos) {
        $repositories = $repositories[0..($MaxRepos - 1)]
        Write-Log “Limited processing to first $MaxRepos repositories”
    }
    # Initialize results array
    $allResults = @()
    # Check if git is available
    try {
        $gitVersion = git –version
        Write-Log “Git is available: $gitVersion”
    }
    catch {
        Write-Log “Git is not available or not in PATH” “ERROR”
        exit 1
    }
    # Process each repository
    $counter = 1
    foreach ($repo in $repositories) {
        Write-Log “Processing repository $counter of $($repositories.Count): $($repo.Repository)”
        # Construct the full git URL
        $gitUrl = $BaseUrl + $repo.Repository
        $repoResults = Process-Repository -RepoName $repo.Repository -RepoUrl $gitUrl
        $allResults += $repoResults
        $counter++
        # Add a small delay to avoid overwhelming the system
        Start-Sleep -Seconds 1
    }
    # Export results to CSV
    try {
        $allResults | Export-Csv -Path $OutputFile -NoTypeInformation
        Write-Log “Results exported to: $OutputFile”
        Write-Log “Total entries: $($allResults.Count)”
    }
    catch {
        Write-Log “Error exporting results: $($_.Exception.Message)” “ERROR”
    }
    # Display summary
    Write-Log “Analysis Summary:”
    $successCount = ($allResults | Where-Object { $_.Status -eq “Success” }).Count
    $noFrameworkCount = ($allResults | Where-Object { $_.Status -eq “No TargetFramework found” }).Count
    $noCsprojCount = ($allResults | Where-Object { $_.Status -eq “No csproj files” }).Count
    $errorCount = ($allResults | Where-Object { $_.Status -like “Error:*” }).Count
    Write-Log “- Successful TargetFramework extractions: $successCount”
    Write-Log “- .csproj files without TargetFramework: $noFrameworkCount”
    Write-Log “- Repositories without .csproj files: $noCsprojCount”
    Write-Log “- Errors: $errorCount”
    # Show sample results
    if ($allResults.Count -gt 0) {
        Write-Log “Sample results:”
        $allResults | Where-Object { $_.TargetFramework -ne “” } | Select-Object Repository, CsprojPath, TargetFramework | Format-Table -AutoSize | Out-String | Write-Host
    }
    Write-Log “Analysis completed successfully!”

}

function Get-CsprojFiles {
    param([string]$RepoPath)
    # Find all .csproj files in the repository
    $csprojFiles = Get-ChildItem -Path $RepoPath -Recurse -Filter “*.csproj” -File -ErrorAction SilentlyContinue
    if ($csprojFiles.Count -eq 0) {
        Write-Log “No .csproj files found in repository: $RepoPath” “WARNING”
        return @()
    }
    else {
        Write-Log “Found $($csprojFiles.Count) .csproj files in $RepoPath”
        return $csprojFiles
    }  

}

function Get-Packages-Updates {
    param([string]$CsprojPath = “C:reposLCM-32ado-reposSET-D365-PDC-DDAppspromptsPackage-Dependencies-Update-Analysis.md”)
    $content = Get-Content $CsprojPath -ErrorAction SilentlyContinue
    if (-not $content) {
        Write-Log “File not found or empty: $CsprojPath” “WARNING”
        return @()
    }
    else {
        Write-Log “File content loaded from: $CsprojPath”
        $PackageReferences = $content | Where-Object { $_ -match ‘<PackageReferences+Include=”([^”]+)”s+Version=”([^”]+)”‘ } | ForEach-Object {
            if ($_ -match ‘<PackageReferences+Include=”([^”]+)”s+Version=”([^”]+)”‘) {
                [PSCustomObject]@{
                    PackageName = $matches[1]
                    Version     = $matches[2]
                }
            }
        }
        return $PackageReferences
    }
    Write-Log “Getting package updates for $CsprojPath”
    return @()

}

function Get-CsProj-Package-References {
    param([string]$CsprojPath)
    try {
        [xml]$csproj = Get-Content $CsprojPath
        $packageReferences = @()
        foreach ($packageRef in $csproj.Project.ItemGroup.PackageReference) {
            $packageReferences += [PSCustomObject]@{
                PackageName = $packageRef.Include
                Version     = $packageRef.Version
            }
        }
        return $packageReferences
    }
    catch {
        Write-Log “Error reading csproj file $CsprojPath`: $($_.Exception.Message)” “ERROR”
        return @()
    }

}

function Invoke-Update-Package-Versions {
    param(
        [string]$CsprojPath,
        [array]$PackagesUpdates
    )
    try {
        [xml]$csproj = Get-Content $CsprojPath
        $updated = $false
        foreach ($packageRef in $csproj.Project.ItemGroup.PackageReference) {
            foreach ($update in $PackagesUpdates) {
                if ($packageRef.Include -eq $update.PackageName) {
                    Write-Log “Updating package $($packageRef.Include) from version $($packageRef.Version) to $($update.Version)”
                    $packageRef.Version = $update.Version
                    $updated = $true
                }
            }
        }
        if ($updated) {
            $csproj.Save($CsprojPath)
            Write-Log “Updated package versions saved to $CsprojPath”
        }
        else {
            Write-Log “No package versions updated in $CsprojPath”
        }
    }
    catch {
        Write-Log “Error updating csproj file $CsprojPath`: $($_.Exception.Message)” “ERROR”
    }

}

function Get-Package-Manual-Updates {
    $packageReferences = @(
        [PSCustomObject]@{ PackageName = “Microsoft.Azure.Functions.Worker.Extensions.CosmosDB”; Version = “4.14.0” },
        [PSCustomObject]@{ PackageName = “Azure.Identity”; Version = “1.13.1” },
        [PSCustomObject]@{ PackageName = “Microsoft.EntityFrameworkCore”; Version = ”8.0.6″ },
        [PSCustomObject]@{ PackageName = “Microsoft.EntityFrameworkCore.SqlServer”; Version=”8.0.6″ 
        }
    )
    return $packageReferences

}

function Get-Package-Manual-Updates-FromFile {
    param ([string]$InputFileName = “C:reposLCM-32ado-reposSET-D365-PDC-DDAppspromptsManual-Updates.xml”)  
    $inputFile = Join-Path $InputFileName
    $content = Get-Content -Raw -ErrorAction Stop -Path $inputFile
    [xml]$xmlContent = $content
    $packageReferences = $xmlContent.PackageReferences.PackageReference | ForEach-Object {
        [PSCustomObject]@{
            PackageName = $_.Include
            Version     = $_.Version
        }
    }
    return $packageReferences

}

function Get-Package-Manual-Updates-IntoFile {
    param ([string]$FolderPath = “C:reposLCM-32ado-reposSET-D365-PDC-DDApps”,
        [string]$OutputFileName = “promptsManual-Updates.xml”)  
    $packageReferences = @( )
    $csprojFiles = Get-CsprojFiles -RepoPath $FolderPath
    $outputFile = Join-Path $FolderPath $OutputFileName
    foreach ($csprojfile in $csprojFiles) {
        $CsprojPath = $csprojfile.FullName
        $packageReferences += Get-CsProj-Package-References -CsprojPath $CsprojPath
    }
    # return unique package references
    $packageReferences = $packageReferences | Sort-Object PackageName -Unique
    # save to file with $packageReferences formated as <PackageReference Include=”” Version=”” />
    $packageReferencesFormatted = $packageReferences | ForEach-Object {
        “<PackageReference Include=`”$($_.PackageName)`” Version=`”$($_.Version)`” />”
    }
    $packageReferencesFormatted | Out-File -FilePath $outputFile -Encoding utf8
    $content = Get-Content -Raw -ErrorAction Stop -Path $outputFile
    $content = “<PackageReferences>`n” + $content + “`n</PackageReferences>”
    Set-Content -Path $outputFile -Value $content -Encoding utf8
    Write-Log “Package manual updates saved to: $outputFile”
    return $packageReferences

}

# — Script to extract BASYSID from multiple repositories —
$Owner = ‘’
$Ref = ‘’   # branch, tag, or commit
$RefTarget = ‘upgrade-to-net10’   # branch, tag, or commit
$FilePath = ‘’  # path to file in repo
$FolderPath = ‘’  # local folder to clone repos
$RepoListFile = ‘’
$ResultsFile = ‘’
$RepoName = ‘’


# Include external functions and secrets
. “$PSScriptRootincl.ps1”
. “../../ecf/seecrets.ps1”

$repoPath = “$FolderPath$RepoName”

# $results = Analyze-CsprojFiles -RepoPath $repoPath -RepoName $RepoName

# C:reposLCM-32ado-reposSET-D365-PDC-DDAppsprompts

# Get-TargetFramework $CsprojPath
$csprojFiles = Get-CsprojFiles -RepoPath $repoPath

$PackagesUpdates = Get-Packages-Updates -CsprojPath “C:reposLCM-32ado-reposSET-D365-PDC-DDAppspromptsPackage-Dependencies-Update-Analysis.md”

# $PackagesManualUpdates = Get-Package-Manual-Updates-FromFile -InputFileName “C:reposLCM-32ado-reposSET-D365-PDC-DDAppspromptsManual-Updates.xml”
$CsprojPath = “C:reposLCM-32ado-reposSET-D365-PDC-DDAppssrcfunctionsSET.D365.PDC.DDApps.Functions.ClaimsSET.D365.PDC.DDApps.Functions.Claims.csproj”

# $PackageReferences = Get-CsProj-Package-References -CsprojPath $CsprojPath
Invoke-Update-Package-Versions -CsprojPath $CsprojPath -PackagesUpdates $PackagesUpdates

# Clean up bin and obj folders
Get-ChildItem .. -include bin, obj -Recurse | foreach ($_) { remove-item $_.fullname -Force -Recurse }

Write-Log “Script execution completed.”

