using Microsoft.EntityFrameworkCore;
using RestAPIDynatrace.Context;

var builder = WebApplication.CreateBuilder(args);

// =======================
// CORS
// =======================
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend",
        policy => policy
            .WithOrigins(
                "http://localhost:5173",
                "https://localhost:5173",
                "https://qsf8ln7q-44334.brs.devtunnels.ms"
            )
            .AllowAnyHeader()
            .AllowAnyMethod()
    );
});

// =======================
// Kestrel (timeouts grandes)
// =======================
builder.WebHost.ConfigureKestrel(serverOptions =>
{
    serverOptions.Limits.MaxRequestBodySize = 1048576000; // 1 GB
    serverOptions.Limits.KeepAliveTimeout = TimeSpan.FromMinutes(10);
    serverOptions.Limits.RequestHeadersTimeout = TimeSpan.FromMinutes(10);
});

// =======================
// SQL Server + Retry automático
// =======================
var connectionString = builder.Configuration.GetConnectionString("Connection");

builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseSqlServer(connectionString, sqlOptions =>
    {
        sqlOptions.EnableRetryOnFailure(
            maxRetryCount: 5,                       // Reintentos
            maxRetryDelay: TimeSpan.FromSeconds(5), // Espera entre intentos
            errorNumbersToAdd: null
        );
    })
);

// =======================
// Controllers & Swagger
// =======================
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// =======================
// Pipeline HTTP
// =======================
app.UseCors("AllowFrontend");

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseAuthorization();
app.MapControllers();

app.Run();