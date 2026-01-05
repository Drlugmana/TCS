using Microsoft.EntityFrameworkCore;
using RestAPIDynatrace.Context;

var builder = WebApplication.CreateBuilder(args);
// Configurar CORS

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
        .AllowAnyMethod());
});


// Configurar Kestrel para aumentar el límite de tamaño de solicitud y el tiempo de espera
builder.WebHost.ConfigureKestrel(serverOptions =>
{
    serverOptions.Limits.MaxRequestBodySize = 1048576000; // 100 MB
    serverOptions.Limits.KeepAliveTimeout = TimeSpan.FromMinutes(10); // Tiempo de espera de Keep-Alive
    serverOptions.Limits.RequestHeadersTimeout = TimeSpan.FromMinutes(10); // Tiempo de espera para los encabezados de la solicitud
});

// Add services to the container.
var connectionString = builder.Configuration.GetConnectionString("Connection");
builder.Services.AddDbContext<AppDbContext>(options => options.UseSqlServer(connectionString));

builder.Services.AddControllers();
// Learn more about configuring Swagger/OpenAPI at https://aka.ms/aspnetcore/swashbuckle
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

var app = builder.Build();

// Configure the HTTP request pipeline.
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
