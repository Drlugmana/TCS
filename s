private static bool _isRunning = false;

protected override async Task ExecuteAsync(CancellationToken stoppingToken)
{
    while (!stoppingToken.IsCancellationRequested)
    {
        if (_isRunning)
        {
            _logger.LogWarning("⏳ El worker sigue ejecutándose, se omite esta iteración.");
            await Task.Delay(5000, stoppingToken);
            continue;
        }

        try
        {
            _isRunning = true;

            // 🔴 IMPORTANTE: ejecutar tokens SECUENCIALMENTE
            foreach (var token in _apiTokens)
            {
                await ProcessDynatraceData(token, stoppingToken);
            }

            _logger.LogInformation(
                "✅ Proceso finalizado. Siguiente actualización en {Seconds} segundos",
                TimeSpan.FromMilliseconds(_timeWaitLoop).TotalSeconds
            );
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "❌ Error general en el Worker Dynatrace");
        }
        finally
        {
            _isRunning = false;
        }

        await Task.Delay(_timeWaitLoop, stoppingToken);
    }
}