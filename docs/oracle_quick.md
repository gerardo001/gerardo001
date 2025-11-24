# Oracle Database Connection with C#

Here's a complete, runnable C# console program that connects to three different Oracle databases, reads data from each, and prints the results.
It uses Oracle Data Provider for .NET (ODP.NET), which is the recommended and high-performance way to work with Oracle in C#.

## C# Code

```csharp
using System;
using System.Data;
using Oracle.ManagedDataAccess.Client; // Install via NuGet: Oracle.ManagedDataAccess

class Program
{
    // Method to fetch data from a given Oracle connection string and query
    static void FetchFromDatabase(string connectionString, string query, string dbName)
    {
        try
        {
            using (OracleConnection conn = new OracleConnection(connectionString))
            {
                conn.Open();
                Console.WriteLine($"\nConnected to {dbName}");

                using (OracleCommand cmd = new OracleCommand(query, conn))
                {
                    using (OracleDataReader reader = cmd.ExecuteReader())
                    {
                        Console.WriteLine($"Data from {dbName}:");
                        if (!reader.HasRows)
                        {
                            Console.WriteLine("No rows returned.");
                        }
                        else
                        {
                            // Print column headers
                            for (int i = 0; i < reader.FieldCount; i++)
                                Console.Write(reader.GetName(i) + "\t");
                            Console.WriteLine();

                            // Print rows
                            while (reader.Read())
                            {
                                for (int i = 0; i < reader.FieldCount; i++)
                                    Console.Write(reader[i] + "\t");
                                Console.WriteLine();
                            }
                        }
                    }
                }
            }
        }
        catch (OracleException ex)
        {
            Console.WriteLine($"Oracle error on {dbName}: {ex.Message}");
        }
        catch (Exception ex)
        {
            Console.WriteLine($"General error on {dbName}: {ex.Message}");
        }
    }

    static void Main()
    {
        // Replace with your actual Oracle DB connection strings
        string connStr1 = "User Id=user1;Password=pass1;Data Source=//host1:1521/service1";
        string connStr2 = "User Id=user2;Password=pass2;Data Source=//host2:1521/service2";
        string connStr3 = "User Id=user3;Password=pass3;Data Source=//host3:1521/service3";

        // Example query (adjust table/columns as needed)
        string query = "SELECT * FROM employees FETCH FIRST 5 ROWS ONLY";

        // Fetch from each database
        FetchFromDatabase(connStr1, query, "Database 1");
        FetchFromDatabase(connStr2, query, "Database 2");
        FetchFromDatabase(connStr3, query, "Database 3");

        Console.WriteLine("\nData retrieval complete.");
    }
}
```

## Setup Instructions

### 1. Install ODP.NET Managed Driver

In your project directory, run:

```bash
dotnet add package Oracle.ManagedDataAccess
```

or in Visual Studio, use NuGet Package Manager.

### 2. Update Connection Strings

Replace:

```csharp
User Id=user;Password=pass;Data Source=//hostname:1521/servicename
```

with your actual Oracle credentials and service names.

### 3. Run the Program

```bash
dotnet run
```

## Features

- Connects to three different Oracle databases sequentially
- Uses `using` statements to ensure connections are closed properly
- Handles Oracle-specific errors and general exceptions
- Prints column headers and data rows dynamically
- Works with any table/query you specify

## Performance Optimization

            If you want, I can also make a parallel version so it queries all three databases at the same time using `Task.WhenAll` for faster performance.
Do you want me to prepare that optimized version?