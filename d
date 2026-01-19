  // GET: api/Problems/ByDateRange/Excel
  [HttpGet("ByDateRange/Excel")]
  public async Task<IActionResult> GetProblemsByDateRangeExcel(
      DateTime startDate, DateTime endDate, string environment, string title = null)
  {
      var query = _context.DynatraceProblems
                  .Where(p => p.StartTime >= startDate && p.StartTime <= endDate && p.Environment == environment);

      if (!string.IsNullOrEmpty(title))
      {
          query = query.Where(p => p.Title.Contains(title));
      }

      var problems = await query.ToListAsync();

      ExcelPackage.LicenseContext = LicenseContext.NonCommercial;

      using (var package = new ExcelPackage())
      {
          var worksheet = package.Workbook.Worksheets.Add("Problemas");

          // Agregar encabezados
          worksheet.Cells[1, 1].Value = "Tenat";
          worksheet.Cells[1, 2].Value = "Impact Level";
          worksheet.Cells[1, 3].Value = "Status";
          worksheet.Cells[1, 4].Value = "Under Maintenance";
          worksheet.Cells[1, 5].Value = "Problem Title";
          worksheet.Cells[1, 6].Value = "Problem Category";
          worksheet.Cells[1, 7].Value = "Severity Level";
          worksheet.Cells[1, 8].Value = "Problem Id";
          worksheet.Cells[1, 9].Value = "Affected Servers";
          worksheet.Cells[1, 10].Value = "Affected Servers Group";
          worksheet.Cells[1, 11].Value = "Impacted Entity";
          worksheet.Cells[1, 12].Value = "Affected Entities Count";
          worksheet.Cells[1, 13].Value = "Root Cause";
          worksheet.Cells[1, 14].Value = "Management Zones";
          worksheet.Cells[1, 15].Value = "Entity Tags";
          worksheet.Cells[1, 16].Value = "Start Time";
          worksheet.Cells[1, 17].Value = "End Time";
          worksheet.Cells[1, 18].Value = "Duration";
          worksheet.Cells[1, 19].Value = "Duration [min]";
          worksheet.Cells[1, 20].Value = "Rango Duracion";
          worksheet.Cells[1, 21].Value = "Mes";
          worksheet.Cells[1, 22].Value = "Comentarios";
          worksheet.Cells[1, 23].Value = "Detalle de Problema";
          worksheet.Cells[1, 24].Value = "Alerting Profiles";
          worksheet.Cells[1, 25].Value = "Problem Link";
          worksheet.Cells[1, 26].Value = "AffectedServerName";
          worksheet.Cells[1, 27].Value = "AffectedServerGroup";
          worksheet.Cells[1, 28].Value = "AffectedServerClass";
          worksheet.Cells[1, 29].Value = "Jurisdiction";

          // Agregar datos
          int row = 2;
          for (int i = 0; i < problems.Count; i++)
          {
              var problem = convertProblemJSON(problems[i]);

              worksheet.Cells[row, 1].Value = $"https://{problem.tenant}.live.dynatrace.com/ui/problems?";
              worksheet.Cells[row, 2].Value = problem.impactLevel ?? "";
              worksheet.Cells[row, 3].Value = problem.status ?? "";
              worksheet.Cells[row, 4].Value = problem.evidenceDetails.details.Any(detail => detail.data?.underMaintenance == true);
              worksheet.Cells[row, 5].Value = problem.title ?? "";
              worksheet.Cells[row, 6].Value = problem.shortDescription ?? "";
              worksheet.Cells[row, 7].Value = problem.severityLevel ?? "";
              worksheet.Cells[row, 8].Value = problem.displayId ?? "";
              worksheet.Cells[row, 9].Value = problem.affectedCI != null ? string.Join(", ", problem.affectedCI.Select(ci => ci.name).Distinct()) : "";
              worksheet.Cells[row, 10].Value = problem.affectedCI != null ? string.Join(", ", problem.affectedCI.Select(ci => ci.group).Distinct()) : "";
              worksheet.Cells[row, 11].Value = string.Join(", ", problem.impactedEntities.Where(e => e.name != null).Select(e => e.name)) ?? "";
              worksheet.Cells[row, 12].Value = problem.affectedEntities.Count;
              worksheet.Cells[row, 13].Value = problem.rootCauseEntity?.name ?? "";
              worksheet.Cells[row, 14].Value = string.Join(", ", problem.managementZones.Where(e => e.name != null).Select(e => e.name)) ?? "";
              worksheet.Cells[row, 15].Value = string.Join(", ", problem.entityTags.Where(e => e.stringRepresentation != null).Select(e => e.stringRepresentation)) ?? "";
              worksheet.Cells[row, 16].Value = problem.startTime;
              worksheet.Cells[row, 16].Style.Numberformat.Format = "dd/mm/yyyy HH:mm:ss";
              DateTime EndTime = (DateTime)(problem.endTime == null ? DateTime.Now : problem.endTime);
              worksheet.Cells[row, 17].Value = EndTime;
              worksheet.Cells[row, 17].Style.Numberformat.Format = "dd/mm/yyyy HH:mm:ss";
              TimeSpan Duration = EndTime - problem.startTime;
              worksheet.Cells[row, 18].Value = Duration.TotalDays;
              worksheet.Cells[row, 18].Style.Numberformat.Format = "d HH:mm:ss";
              worksheet.Cells[row, 19].Value = Duration.TotalMinutes;
              worksheet.Cells[row, 20].Value = Duration.TotalMinutes <= 1 ? "Hasta 1 minuto" :
                  Duration.TotalMinutes <= 5 ? "Hasta 5 minutos" :
                  Duration.TotalMinutes <= 10 ? "Hasta 10 minutos" :
                  Duration.TotalMinutes <= 30 ? "Hasta 30 minutos" :
                  Duration.TotalMinutes <= 60 ? "Hasta 1 hora" :
                  Duration.TotalMinutes <= 360 ? "Hasta 6 horas" :
                  Duration.TotalMinutes <= 720 ? "Hasta 12 horas" :
                  Duration.TotalMinutes <= 1440 ? "Hasta 1 dia" : "Mas de 1 dia";
              worksheet.Cells[row, 21].Value = problem.startTime.ToString("MMM-yy");
              string allComments = "";
              foreach (var comment in problem.recentComments.comments)
              {
                  allComments += "COMENTARIO\r\n";
                  if (!string.IsNullOrEmpty(comment.authorName))
                  {
                      allComments += $"{comment.authorName}\r\n";
                  }
                  if (!string.IsNullOrEmpty(comment.content))
                  {
                      allComments += $"{comment.content}\r\n";
                  }
                  if (!string.IsNullOrEmpty(comment.context))
                  {
                      allComments += $"{comment.context}\r\n";
                  }
              }
              worksheet.Cells[row, 22].Value = allComments;
              string evidenceDetails = "";
              foreach (var detail in problem.evidenceDetails.details)
              {
                  string aux = "DETALLE\r\n";
                  aux = string.IsNullOrEmpty(detail.entity.name) ? "" : $"{detail.entity.name}\r\n";
                  aux += string.IsNullOrEmpty(detail.displayName) ? "" : $"{detail.displayName}\r\n";

                  if (detail.data != null && detail.data.properties != null)
                  {
                      var properties = detail.data.properties;
                      string description = properties.FirstOrDefault(prop => prop.key == "dt.event.description")?.value ?? string.Empty;
                      string affectedRequest = properties.FirstOrDefault(prop => prop.key == "dt.event.baseline.affected_load")?.value ?? string.Empty;

                      aux += string.IsNullOrEmpty(description) ? "" : $"{description}\r\n";
                      aux += string.IsNullOrEmpty(affectedRequest) ? "" : $"Affected request: {affectedRequest} /min\r\n";
                  }

                  evidenceDetails += $"{aux}";
              }
              worksheet.Cells[row, 23].Value = evidenceDetails;
              worksheet.Cells[row, 24].Value = string.Join(", ", problem.problemFilters.Where(e => e.name != null).Select(e => e.name)) ?? "";
              worksheet.Cells[row, 25].Value = $@"https://{problem.tenant}.live.dynatrace.com/#problems/problemdetails;pid={problem.problemId}" ?? "";

              worksheet.Cells[row, 26].Value = problem.affectedCI != null ? string.Join(", ", problem.affectedCI
                                              .Where(ci => ci.name != null)
                                              .Select(ci => ci.name)
                                              .Distinct()) : "";
              worksheet.Cells[row, 27].Value = problem.affectedCI != null ? string.Join(", ", problem.affectedCI
                                              .Where(ci => ci.group != null)
                                              .Select(ci => ci.group)
                                              .Distinct()) : "";
              worksheet.Cells[row, 28].Value = problem.affectedCI != null ? string.Join(", ", problem.affectedCI
                                              .Where(ci => ci.serverClass != null)
                                              .Select(ci => ci.serverClass)
                                              .Distinct()) : "";
              worksheet.Cells[row, 29].Value = string.IsNullOrWhiteSpace(problem.jurisdiction) ? " "
                                              : problem.jurisdiction;
              row++;
          }

          var stream = new MemoryStream();
          package.SaveAs(stream);
          stream.Position = 0;

          var fileName = $"Problems_{environment}_{startDate:yyyy-MM-dd}_{endDate.AddMinutes(-1):yyyy-MM-dd}.xlsx";
          return File(stream, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", fileName);
      }
  }
