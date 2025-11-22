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

Here’s a complete, working example of how to connect to an Azure SQL Database using Managed Identity in Azure PowerShell.

When using Managed Identity, you do not store credentials in the connection string — instead, you acquire an access token from Azure AD and pass it to the SQL connection.

Azure PowerShell Script
```powershell
# Ensure Az module is installed and imported
# Install-Module -Name Az -Scope CurrentUser -Repository PSGallery -Force
Import-Module Az.Accounts

# Login to Azure (if running locally, this will use your Azure account)
Connect-AzAccount

# Variables
$serverName = "your-sql-server-name.database.windows.net"
$databaseName = "your-database-name"

# Get an access token for Azure SQL using Managed Identity
# If running inside Azure (VM, App Service, Function) with Managed Identity enabled,
# use Connect-AzAccount -Identity instead of interactive login.
$accessToken = (Get-AzAccessToken -ResourceUrl "https://database.windows.net/").Token

# Build the connection string WITHOUT username/password
$connectionString = "Server=tcp:$serverName,1433;Database=$databaseName;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"

# Load .NET SQL client
Add-Type -AssemblyName "System.Data"

# Create and open SQL connection using AccessToken
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString
$connection.AccessToken = $accessToken
$connection.Open()

Write-Host "Connected successfully to $databaseName on $serverName using Managed Identity."

# Example query
$command = $connection.CreateCommand()
$command.CommandText = "SELECT TOP 5 name FROM sys.databases"
$reader = $command.ExecuteReader()

while ($reader.Read()) {
    Write-Host $reader["name"]
}

# Cleanup
$reader.Close()
$connection.Close()

# Key Points
# No credentials are stored — authentication is handled by Azure AD via Managed Identity.
# The connection string looks like:

Server=tcp:<server>.database.windows.net,1433;
Database=<database>;
Encrypt=True;
TrustServerCertificate=False;
Connection Timeout=30;
You do not include User ID or Password when using Managed Identity.
The AccessToken is retrieved with:

# Get-AzAccessToken -ResourceUrl "https://database.windows.net/"
# If running inside Azure (VM, App Service, Function), replace:

Connect-AzAccount
# with:

Connect-AzAccount -Identity
```

RE Write connection string to Connect to an Azure SQL server using managed identity using Azure PowerShell
