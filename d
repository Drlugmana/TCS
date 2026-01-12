// src/components/ProblemCard.jsx
import React, { useEffect, useMemo, useState } from "react";
import { useBiaCatalog } from "../context/BiaCatalogContext";
import {
  getSlaMinutes,
  getColorByPercent,
  calcularCriticidadDetallada,
  getButtonColorByPercent,
} from "../utils/slaUtils";

// Helpers para soportar campos con mayúsculas/minúsculas
function pick(p, ...keys) {
  for (const k of keys) {
    if (p && p[k] !== undefined && p[k] !== null) return p[k];
  }
  return undefined;
}

// Normaliza estado OPEN/CLOSED (sin inventar OPEN si viene CLOSED)
function normalizeStatus(p) {
  const raw =
    pick(p, "status", "Status", "problemStatus", "problemState", "ProblemStatus", "ProblemState") ?? "";
  const s = String(raw || "").trim().toUpperCase();

  if (s.includes("OPEN")) return "OPEN";
  if (s.includes("CLOSED") || s.includes("RESOLVED")) return "CLOSED";

  // fallback solo si no vino status
  const end = pick(p, "endTime", "EndTime");
  return end ? "CLOSED" : "OPEN";
}

// Normaliza Environment (Productivo/No Productivo)
function normalizeEnvironment(raw) {
  const s = String(raw || "").trim().toUpperCase().replace(/\s+/g, "");
  if (s === "PRODUCTIVO") return "Productivo";
  if (s.includes("NOPRODUCTIVO") || s.includes("NO")) return "NoProductivo";
  return raw || "";
}

// Iconos por tower
function towerToIconPath(towerKey) {
  if (!towerKey) return null;
  const key = String(towerKey).toLowerCase();

  if (key.includes("wintel") || key.includes("windows")) return "/icons/towers/wiltel1.svg";
  if (key.includes("bdd") || key.includes("base de datos") || key.includes("database") || key.includes("bd"))
    return "/icons/towers/Base.svg";
  if (key.includes("unix") || key.includes("aix") || key.includes("linux")) return "/icons/towers/unix.svg";
  if (key.includes("storage") || key.includes("respaldo") || key.includes("backup")) return "/icons/towers/sto.svg";

  return null;
}

export default function ProblemCard({ problem }) {
  const { get: catalogGet } = useBiaCatalog();

  const status = useMemo(() => normalizeStatus(problem), [problem]);

  function formatDateTimeDMY(date) {
    if (!date) return "--";
    const d = new Date(date);

    const dd = String(d.getDate()).padStart(2, "0");
    const mm = String(d.getMonth() + 1).padStart(2, "0");
    const yyyy = d.getFullYear();
    const fecha = `${dd}/${mm}/${yyyy}`;

    const hora = d.toLocaleTimeString("en-US", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hour12: true,
    });

    return `${fecha}, ${hora}`;
  }

  // ✅ soporta startTime / StartTime
  const start = useMemo(() => {
    const raw = pick(problem, "startTime", "StartTime");
    return raw ? new Date(raw) : new Date();
  }, [problem]);

  // Buscar coincidencia con catálogo
  const hitFromCatalog = useMemo(() => {
    const arr = Array.isArray(problem?.affectedCI) ? problem.affectedCI : [];
    for (const ci of arr) {
      const name = ci?.name || ci?.Nombre;
      const hit = name ? catalogGet(name) : null;
      if (hit) return hit;
    }
    return null;
  }, [problem, catalogGet]);

  const towerIcon = towerToIconPath(hitFromCatalog?.tower);

  const { criticidad } = calcularCriticidadDetallada(problem, {
    catalogLookup: (ciName) => catalogGet(ciName),
  });

  // SLA
  const slaMinutes = getSlaMinutes(criticidad);

  // Timer: SOLO si está OPEN
  const [now, setNow] = useState(new Date());

  useEffect(() => {
    if (status === "CLOSED") return;
    const interval = setInterval(() => setNow(new Date()), 1000);
    return () => clearInterval(interval);
  }, [status]);

  const elapsedMinutes = useMemo(() => (status === "CLOSED" ? 0 : (now - start) / 60000), [now, start, status]);
  const remainingMinutes = useMemo(
    () => (status === "CLOSED" ? 0 : Math.max(slaMinutes - elapsedMinutes, 0)),
    [slaMinutes, elapsedMinutes, status]
  );

  const percentRemaining = useMemo(() => {
    if (status === "CLOSED") return 100;
    return Math.max((remainingMinutes / slaMinutes) * 100, 0);
  }, [remainingMinutes, slaMinutes, status]);

  const bgColor = getColorByPercent(percentRemaining);
  const buttonColor = getButtonColorByPercent(percentRemaining);

  const formatTime = (minutes) => {
    const totalSeconds = Math.floor(minutes * 60);
    const hrs = Math.floor(totalSeconds / 3600);
    const mins = Math.floor((totalSeconds % 3600) / 60);
    const secs = totalSeconds % 60;
    return `${String(hrs).padStart(2, "0")}:${String(mins).padStart(2, "0")}:${String(secs).padStart(2, "0")}`;
  };

  const affected = Array.isArray(problem?.affectedCI) ? problem.affectedCI : [];
  const uniqueNames = [...new Set(affected.map((ci) => ci?.name).filter(Boolean))];
  const equipos = uniqueNames.join(", ");

  // ✅ Botón SIEMPRE funcional (solo se deshabilita si no hay URL válida)
  const tenant = pick(problem, "tenant", "Tenant") || "";
  const problemId = pick(problem, "problemId", "ProblemId", "displayId", "DisplayId") || "";

  const dynatraceUrl =
    tenant && problemId
      ? `https://${tenant}.live.dynatrace.com/#problems/problemdetails;pid=${problemId}`
      : "#";

  const environmentRaw = pick(problem, "environment", "Environment") || "";
  const environment = normalizeEnvironment(environmentRaw);

  // ✅ AJUSTES PARA QUE ENTREN MÁS TARJETAS EN PANTALLA
  const TITLE_FS = "1.15rem";
  const TEXT_FS = ".95rem";
  const ICON_SIZE = 70;

  return (
    <div
      style={{
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",
        borderRadius: "12px",
        padding: ".6rem 1rem",          // ⬅️ antes 1rem 1.5rem
        marginBottom: ".6rem",          // ⬅️ antes 1rem
        backgroundColor: bgColor,
        boxShadow: "0 4px 10px rgba(0,0,0,.1)",
      }}
    >
      {/* IZQUIERDA: INFO */}
      <div style={{ flex: 1, paddingRight: ".8rem" }}>
        <h3 style={{ margin: 0, fontSize: TITLE_FS, fontWeight: "bold", lineHeight: 1.1 }}>
          {pick(problem, "title", "Title") || "(sin título)"}
        </h3>

        <p style={{ fontSize: TEXT_FS, margin: ".25rem 0" }}>
          <strong>Severidad Dynatrace:</strong> {pick(problem, "severityLevel", "SeverityLevel")}
        </p>
        <p style={{ fontSize: TEXT_FS, margin: ".25rem 0" }}>
          <strong>Impacto:</strong> {pick(problem, "impactLevel", "ImpactLevel")}
        </p>
        <p style={{ fontSize: TEXT_FS, margin: ".25rem 0" }}>
          <strong>Inicio:</strong> {formatDateTimeDMY(start)}
        </p>
        <p style={{ fontSize: TEXT_FS, margin: ".25rem 0" }}>
          <strong>Estado:</strong> {status}
        </p>
        <p style={{ fontSize: TEXT_FS, margin: ".25rem 0" }}>
          <strong>Criticidad (BIA):</strong> {criticidad}
        </p>

        <p style={{ fontSize: TEXT_FS, margin: ".25rem 0" }}>
          <strong>Equipos afectados:</strong>{" "}
          <small
            title={equipos}
            style={{
              display: "inline-block",
              maxWidth: 360,
              whiteSpace: "nowrap",
              overflow: "hidden",
              textOverflow: "ellipsis",
              verticalAlign: "bottom",
            }}
          >
            {equipos}
          </small>
        </p>
      </div>

      {/* CENTRO: ICONOS */}
      <div
        style={{
          display: "flex",
          justifyContent: "center",
          alignItems: "center",
          gap: ".6rem",                 // ⬅️ menos gap
          flexShrink: 0,
          minWidth: "170px",            // ⬅️ antes 220px
        }}
      >
        <img
          src={`/severidad${criticidad}.svg`}
          width={ICON_SIZE}
          height={ICON_SIZE}
          title={`Criticidad ${criticidad}`}
          alt={`Criticidad ${criticidad}`}
        />
        <img
          src={environment === "Productivo" ? "/icon-productivo.svg" : "/icon-noproductivo.svg"}
          width={ICON_SIZE}
          height={ICON_SIZE}
          title={environmentRaw}
          alt={environmentRaw}
        />
        {towerIcon && (
          <img
            src={towerIcon}
            alt="tower"
            width={ICON_SIZE}
            height={ICON_SIZE}
            title={hitFromCatalog?.towerRaw || hitFromCatalog?.tower}
          />
        )}
      </div>

      {/* DERECHA: TIMER + BOTÓN */}
      <div style={{ textAlign: "center", minWidth: "130px" }}>
        <div style={{ fontSize: "1.4rem", fontWeight: "bold" }}>{formatTime(remainingMinutes)}</div>

        <button
          disabled={dynatraceUrl === "#"}
          onClick={() => window.open(dynatraceUrl, "_blank")}
          style={{
            marginTop: ".35rem",
            padding: ".35rem .8rem",
            fontSize: ".85rem",
            fontWeight: "bold",
            color: "#fff",
            backgroundColor: status === "CLOSED" ? "#6b7280" : buttonColor,
            border: "none",
            borderRadius: "8px",
            cursor: dynatraceUrl === "#" ? "not-allowed" : "pointer",
            opacity: dynatraceUrl === "#" ? 0.7 : 1,
          }}
        >
          Revisar problema
        </button>
      </div>
    </div>
  );
}