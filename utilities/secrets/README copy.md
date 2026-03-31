# Introduction 
TODO: Give a short introduction of your project. Let this section explain the objectives or the motivation behind this project. 

# Getting Started
TODO: Guide users through getting your code up and running on their own system. In this section you can talk about:
1.	Installation process
2.	Software dependencies
3.	Latest releases
4.	API references

# Build and Test
TODO: Describe and show how to build your code and run the tests. 

# Azure Key Vault Secrets Script
Use the PowerShell script in [scripts/azure-keyvault-upsert-secrets.ps1](scripts/azure-keyvault-upsert-secrets.ps1) to create or update secrets in an Azure Key Vault.

Prerequisites:
1. Azure CLI installed.
2. Signed in with `az login`.
3. Access permissions to set secrets on the target Key Vault.

Input file format:
- Object map (see [scripts/secrets.sample.json](scripts/secrets.sample.json)).
- Or array of objects with `name` and `value`.

Example command:

```powershell
pwsh ./scripts/azure-keyvault-upsert-secrets.ps1 -VaultName my-keyvault -SecretsFile ./scripts/secrets.sample.json
```

With explicit subscription and pipeline-friendly output:

```powershell
pwsh ./scripts/azure-keyvault-upsert-secrets.ps1 -VaultName my-keyvault -SecretsFile ./scripts/secrets.sample.json -SubscriptionId 00000000-0000-0000-0000-000000000000 -PassThru
```

# Contribute
TODO: Explain how other users and developers can contribute to make your code better. 

If you want to learn more about creating good readme files then refer the following [guidelines](https://docs.microsoft.com/en-us/azure/devops/repos/git/create-a-readme?view=azure-devops). You can also seek inspiration from the below readme files:
- [ASP.NET Core](https://github.com/aspnet/Home)
- [Visual Studio Code](https://github.com/Microsoft/vscode)
- [Chakra Core](https://github.com/Microsoft/ChakraCore)