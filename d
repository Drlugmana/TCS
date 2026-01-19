

      [HttpGet("latest")]
      public async Task<ActionResult<PagedResponse<ProblemDynatraceResponse>>> GetProblemsLatest(
    [FromQuery] int pageNumber = 1,
    [FromQuery] int pageSize = 50,
    [FromQuery] string? jurisdiction = null
)
      {
          // Ventana de tiempo para CLOSED recientes (ajústalo si quieres)
          var closedStartDate = DateTime.Today.AddDays(-2);
          var now = DateTime.Now;

          // 1) TODOS los OPEN (sin paginación aquí, para no "perder" ninguno)
          var openQuery = _context.DynatraceProblems
              .AsNoTracking()
              .Where(p => p.Status == "OPEN");

          // Si te mandan jurisdiction por querystring (ej: TCS), lo aplicamos.
          if (!string.IsNullOrWhiteSpace(jurisdiction))
              openQuery = openQuery.Where(p => p.Jurisdiction == jurisdiction);

          // 2) POCOS CLOSED recientes (últimos 1-2 días) para que el Front tenga cerradas
          //    Aquí sí limitamos cantidad (Top 50 por defecto)
          var closedTop = 50;

          var closedQuery = _context.DynatraceProblems
              .AsNoTracking()
              .Where(p => p.Status == "CLOSED"
                       && p.StartTime >= closedStartDate
                       && p.StartTime <= now);

          if (!string.IsNullOrWhiteSpace(jurisdiction))
              closedQuery = closedQuery.Where(p => p.Jurisdiction == jurisdiction);

          // Traemos a memoria: todos los OPEN + top CLOSED recientes
          var openList = await openQuery
              .OrderByDescending(p => p.StartTime)
              .ToListAsync();

          var closedList = await closedQuery
              .OrderByDescending(p => p.StartTime)
              .Take(closedTop)
              .ToListAsync();

          // 3) Unimos (sin duplicados por ProblemId) y ordenamos por StartTime desc
          var merged = openList
              .Concat(closedList)
              .GroupBy(p => p.ProblemId)
              .Select(g => g.First())
              .OrderByDescending(p => p.StartTime)
              .ToList();

          // 4) Paginación sobre el MERGE final (así ya no se "pierden" OPEN)
          var totalRecords = merged.Count;

          var page = merged
              .Skip((pageNumber - 1) * pageSize)
              .Take(pageSize)
              .ToList();

          // 5) Tu misma lógica de deserialización (sin cambiar tu método)
          var deserializedProblems = page
              .Select(problem =>
              {
                  try
                  {
                      return convertProblemJSON(problem);
                  }
                  catch (JsonException)
                  {
                      return null;
                  }
              })
              .Where(p => p != null)
              .ToList()!;

          var response = new PagedResponse<ProblemDynatraceResponse>
          {
              TotalRecords = totalRecords,
              TotalPages = (int)Math.Ceiling(totalRecords / (double)pageSize),
              PageNumber = pageNumber,
              PageSize = pageSize,
              Data = deserializedProblems
          };

          return response;
      }
