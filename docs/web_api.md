Here’s a complete, runnable example of a .NET Core Web API secured with OAuth 2.0 and OpenID Connect (OIDC) authentication using JWT Bearer tokens.
This setup works with any OIDC-compliant provider (e.g., IdentityServer, Auth0, Azure AD, Okta).

1️⃣ Project Setup
```
dotnet new webapi -n SecureApi
cd SecureApi
```

2️⃣ Install Required Packages
```
dotnet add package Microsoft.AspNetCore.Authentication.JwtBearer
```

3️⃣ Configure Authentication in Program.cs
```[csharp]
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.Text;

var builder = WebApplication.CreateBuilder(args);

// Add authentication with JWT Bearer
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        // Authority = your OAuth/OIDC provider's URL (e.g., Auth0, Azure AD, IdentityServer)
        options.Authority = "https://your-identity-provider.com";

        // Audience = API identifier registered in your identity provider
        options.Audience = "your-api-audience";

        // Token validation parameters
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true
        };

        // Optional: Debugging events
        options.Events = new JwtBearerEvents
        {
            OnAuthenticationFailed = context =>
            {
                Console.WriteLine($"Authentication failed: {context.Exception.Message}");
                return Task.CompletedTask;
            },
            OnTokenValidated = context =>
            {
                Console.WriteLine($"Token valid for: {context.Principal.Identity?.Name}");
                return Task.CompletedTask;
            }
        };
    });

builder.Services.AddAuthorization();
builder.Services.AddControllers();

var app = builder.Build();

app.UseHttpsRedirection();
app.UseAuthentication(); // Must come before UseAuthorization
app.UseAuthorization();

app.MapControllers();

app.Run();
```

4️⃣ Create a Protected Controller
```[csharp]
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace SecureApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class SecureDataController : ControllerBase
    {
        // This endpoint requires a valid JWT token
        [HttpGet("private")]
        [Authorize]
        public IActionResult GetPrivateData()
        {
            return Ok(new
            {
                Message = "You have accessed a protected endpoint!",
                User = User.Identity?.Name
            });
        }

        // Public endpoint (no authentication required)
        [HttpGet("public")]
        [AllowAnonymous]
        public IActionResult GetPublicData()
        {
            return Ok(new { Message = "This is public data." });
        }
    }
}
```

5️⃣ appsettings.json Example
```[json]
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "Jwt": {
    "Authority": "https://your-identity-provider.com",
    "Audience": "your-api-audience"
  }
}
```

6️⃣ How It Works
Client logs in via your OAuth/OIDC provider (Auth0, Azure AD, etc.).
Provider issues a JWT access token.
Client sends requests to your API with:
Authorization: Bearer <access_token>

API validates the token against the Authority and Audience.
If valid, the request proceeds; otherwise, it returns 401 Unauthorized.
7️⃣ Testing with curl
# Public endpoint
'''
curl https://localhost:5001/api/securedata/public
```

# Private endpoint (replace <token> with a valid JWT)
```
curl -H "Authorization: Bearer <token>" https://localhost:5001/api/securedata/private
```

✅ Security Best Practices

Always use HTTPS.
Enable PKCE for public clients.
Keep Authority and Audience in configuration, not hardcoded.
Rotate signing keys regularly in your identity provider.

If you want, I can extend this example to include a built-in IdentityServer so you can run OAuth + OIDC without an external provider for local development.
Do you want me to prepare that version?
