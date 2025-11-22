[Connect to an Azure SQL server using an Azure Private Endpoint](https://learn.microsoft.com/en-us/azure/private-link/tutorial-private-endpoint-sql-powershell)
```powershell
# Ensure Az module is installed and imported
try {
    if (-not (Get-Module -ListAvailable -Name Az)) {
        Install-Module -Name Az -Scope CurrentUser -Force
    }
    Import-Module Az
} catch {
    Write-Error "Failed to install or import Az module: $_"
    exit 1
}

# Variables - replace with your actual values
$resourceGroup = "MyResourceGroup"
$sqlServerName = "myazuresqlserver"   # Without .database.windows.net
$databaseName  = "MyDatabase"
$sqlUser       = "sqladmin"
$sqlPassword   = "P@ssw0rd123!"       # Use a secure method in production

# Get the private endpoint connection (optional verification)
try {
    $privateEndpoint = Get-AzPrivateEndpointConnection `
        -ResourceGroupName $resourceGroup `
        -Name $sqlServerName -ErrorAction Stop
    Write-Host "Private Endpoint found for SQL Server: $($privateEndpoint.Name)"
} catch {
    Write-Warning "Could not retrieve Private Endpoint details: $_"
}

# Build the connection string
# IMPORTANT: Use the private endpoint's FQDN (usually same as public FQDN)
$serverFqdn = "$sqlServerName.database.windows.net"

$connectionString = "Server=tcp:$serverFqdn,1433;Initial Catalog=$databaseName;Persist Security Info=False;User ID=$sqlUser;Password=$sqlPassword;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

Write-Host "Connection String:" -ForegroundColor Cyan
Write-Host $connectionString

# Optional: Test connection using .NET SqlClient
try {
    Add-Type -AssemblyName "System.Data"
    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $connectionString
    $connection.Open()
    Write-Host "✅ Successfully connected to Azure SQL via Private Endpoint."
    $connection.Close()
} catch {
    Write-Error "❌ Connection failed: $_"
}
```



RE: Write connection string to Connect to an Azure SQL server using an Azure Private Endpoint using Azure PowerShell
