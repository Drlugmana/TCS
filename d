public string? Comentarios { get; set; }
public string? DetalleDeProblema { get; set; }

[HttpGet("latest")]
public async Task<ActionResult<PagedResponse<ProblemDynatraceResponse>>> GetProblemsLatest(
    [FromQuery] int pageNumber = 1,
    [FromQuery] int pageSize = 50,
    [FromQuery] string? jurisdiction = null
)
{
    var closedStartDate = DateTime.Today.AddDays(-2);
    var now = DateTime.Now;

    // 1) TODOS los OPEN
    var openQuery = _context.DynatraceProblems
        .AsNoTracking()
        .Where(p => p.Status == "OPEN");

    if (!string.IsNullOrWhiteSpace(jurisdiction))
        openQuery = openQuery.Where(p => p.Jurisdiction == jurisdiction);

    // 2) CLOSED recientes (Top N)
    var closedTop = 50;

    var closedQuery = _context.DynatraceProblems
        .AsNoTracking()
        .Where(p => p.Status == "CLOSED"
                 && p.StartTime >= closedStartDate
                 && p.StartTime <= now);

    if (!string.IsNullOrWhiteSpace(jurisdiction))
        closedQuery = closedQuery.Where(p => p.Jurisdiction == jurisdiction);

    var openList = await openQuery
        .OrderByDescending(p => p.StartTime)
        .ToListAsync();

    var closedList = await closedQuery
        .OrderByDescending(p => p.StartTime)
        .Take(closedTop)
        .ToListAsync();

    // 3) Merge sin duplicados
    var merged = openList
        .Concat(closedList)
        .GroupBy(p => p.ProblemId)
        .Select(g => g.First())
        .OrderByDescending(p => p.StartTime)
        .ToList();

    // 4) Paginación final
    var totalRecords = merged.Count;

    var page = merged
        .Skip((pageNumber - 1) * pageSize)
        .Take(pageSize)
        .ToList();

    // ✅ Helpers iguales al Excel pero para devolver string
    static string BuildComments(RecentComments? recentComments)
    {
        if (recentComments?.comments == null || recentComments.comments.Count == 0)
            return "";

        var sb = new StringBuilder();

        foreach (var comment in recentComments.comments)
        {
            sb.AppendLine("COMENTARIO");

            if (!string.IsNullOrWhiteSpace(comment.authorName))
                sb.AppendLine(comment.authorName);

            if (!string.IsNullOrWhiteSpace(comment.content))
                sb.AppendLine(comment.content);

            if (!string.IsNullOrWhiteSpace(comment.context))
                sb.AppendLine(comment.context);

            sb.AppendLine();
        }

        return sb.ToString().Trim();
    }

    static string BuildEvidenceDetails(EvidenceDetails? evidenceDetails)
    {
        if (evidenceDetails?.details == null || evidenceDetails.details.Count == 0)
            return "";

        var sb = new StringBuilder();

        foreach (var detail in evidenceDetails.details)
        {
            sb.AppendLine("DETALLE");

            var entityName = detail?.entity?.name;
            if (!string.IsNullOrWhiteSpace(entityName))
                sb.AppendLine(entityName);

            if (!string.IsNullOrWhiteSpace(detail?.displayName))
                sb.AppendLine(detail.displayName);

            var properties = detail?.data?.properties;
            if (properties != null && properties.Count > 0)
            {
                var description = properties.FirstOrDefault(p => p.key == "dt.event.description")?.value ?? "";
                var affectedRequest = properties.FirstOrDefault(p => p.key == "dt.event.baseline.affected_load")?.value ?? "";

                if (!string.IsNullOrWhiteSpace(description))
                    sb.AppendLine(description);

                if (!string.IsNullOrWhiteSpace(affectedRequest))
                    sb.AppendLine($"Affected request: {affectedRequest} /min");
            }

            sb.AppendLine();
        }

        return sb.ToString().Trim();
    }

    // 5) Deserialización + set de 2 columnas nuevas
    var deserializedProblems = page
        .Select(dbProblem =>
        {
            try
            {
                var p = convertProblemJSON(dbProblem);

                // ✅ Aquí agregas las 2 “columnas” como strings
                p.Comentarios = BuildComments(p.recentComments);
                p.DetalleDeProblema = BuildEvidenceDetails(p.evidenceDetails);

                return p;
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