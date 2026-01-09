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
  // si viene "Productivo"
  if (s === "PRODUCTIVO") return "Productivo";
  // si viene "NoProductivo", "No Productivo", etc.
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

export default function ProblemCard({ problem, username }) {
  const { get: catalogGet } = useBiaCatalog();

  const status = useMemo(() => normalizeStatus(problem), [problem]);

  function formatDateTimeDMY(date) {
    if (!date) return "--";

    const d = new Date(date);

    // ✅ Fecha fija: DD/MM/YYYY
    const dd = String(d.getDate()).padStart(2, "0");
    const mm = String(d.getMonth() + 1).padStart(2, "0");
    const yyyy = d.getFullYear();
    const fecha = `${dd}/${mm}/${yyyy}`;

    // ✅ Hora igual que antes (AM/PM)
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
    if (status === "CLOSED") return; // NO corre en CLOSED
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

  const isDisabled = !username;

  // ✅ soporta tenant/Tenant + problemId/displayId/ProblemId/DisplayId
  const tenant = pick(problem, "tenant", "Tenant") || "";
  const problemId = pick(problem, "problemId", "ProblemId", "displayId", "DisplayId") || "";

  const dynatraceUrl =
    tenant && problemId
      ? `https://${tenant}.live.dynatrace.com/#problems/problemdetails;pid=${problemId}`
      : "#";

  // ✅ soporta environment/Environment y normaliza valores
  const environmentRaw = pick(problem, "environment", "Environment") || "";
  const environment = normalizeEnvironment(environmentRaw);

  // ==========================
  // ✅ SOLO CAMBIO DE ESTILO
  // ==========================
  const iconSize = 86; // más compacto tipo “tile”

  return (
    <div
      style={{
        backgroundColor: bgColor,
        borderRadius: "18px",
        padding: "16px",
        boxShadow: "0 10px 25px rgba(0,0,0,.16)",
        border: "1px solid rgba(255,255,255,.35)",
        // ✅ clave para look de “tarjeta” (y que en grid se vea bien)
        display: "grid",
        gridTemplateColumns: "1fr auto",
        gridTemplateRows: "auto 1fr auto",
        gap: "12px",
        // ✅ NO fuerza fila larga; se adapta a grid del contenedor
        width: "100%",
        minHeight: "230px",
        marginBottom: "14px",
      }}
    >
      {/* TITULO (fila 1) */}
      <div style={{ gridColumn: "1 / 3" }}>
        <h3 style={{ margin: 0, fontSize: "1.35rem", fontWeight: 800, lineHeight: 1.2 }}>
          {pick(problem, "title", "Title") || "(sin título)"}
        </h3>
      </div>

      {/* INFO (columna izquierda) */}
      <div style={{ gridColumn: "1 / 2" }}>
        <div style={{ fontSize: "1.02rem", lineHeight: 1.55 }}>
          <div>
            <strong>Severidad Dynatrace:</strong> {pick(problem, "severityLevel", "SeverityLevel")}
          </div>
          <div>
            <strong>Impacto:</strong> {pick(problem, "impactLevel", "ImpactLevel")}
          </div>
          <div>
            <strong>Inicio:</strong> {formatDateTimeDMY(start)}
          </div>
          <div>
            <strong>Estado:</strong> {status}
          </div>
          <div>
            <strong>Criticidad (BIA):</strong> {criticidad}
          </div>
          <div style={{ marginTop: 6 }}>
            <strong>Equipos afectados:</strong>{" "}
            <span style={{ fontSize: ".92rem", opacity: 0.95 }}>{equipos}</span>
          </div>
        </div>
      </div>

      {/* ICONOS (columna derecha) */}
      <div
        style={{
          gridColumn: "2 / 3",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          gap: "10px",
          paddingLeft: "6px",
          minWidth: "110px",
        }}
      >
        <img
          src={`/severidad${criticidad}.svg`}
          width={iconSize}
          height={iconSize}
          title={`Criticidad ${criticidad}`}
          alt={`Criticidad ${criticidad}`}
          style={{ filter: "drop-shadow(0 8px 12px rgba(0,0,0,.18))" }}
        />

        <img
          src={environment === "Productivo" ? "/icon-productivo.svg" : "/icon-noproductivo.svg"}
          width={iconSize}
          height={iconSize}
          title={environmentRaw}
          alt={environmentRaw}
          style={{ filter: "drop-shadow(0 8px 12px rgba(0,0,0,.18))" }}
        />

        {towerIcon && (
          <img
            src={towerIcon}
            alt="tower"
            width={iconSize}
            height={iconSize}
            title={hitFromCatalog?.towerRaw || hitFromCatalog?.tower}
            style={{ filter: "drop-shadow(0 8px 12px rgba(0,0,0,.18))" }}
            onError={(e) => {
              // evita ícono roto en UI
              e.currentTarget.style.display = "none";
            }}
          />
        )}
      </div>

      {/* FOOTER (timer + botón) */}
      <div
        style={{
          gridColumn: "1 / 3",
          display: "flex",
          justifyContent: "space-between",
          alignItems: "center",
          gap: "12px",
          marginTop: "6px",
        }}
      >
        <div style={{ fontSize: "1.65rem", fontWeight: 900 }}>
          {formatTime(remainingMinutes)}
        </div>

        <button
          disabled={isDisabled || dynatraceUrl === "#"}
          onClick={() => window.open(dynatraceUrl, "_blank")}
          style={{
            padding: "10px 14px",
            fontSize: ".95rem",
            fontWeight: 800,
            color: "#fff",
            backgroundColor: isDisabled ? "#b0b0b0" : status === "CLOSED" ? "#6b7280" : buttonColor,
            border: "none",
            borderRadius: "12px",
            cursor: isDisabled ? "not-allowed" : "pointer",
            boxShadow: "0 10px 20px rgba(0,0,0,.18)",
            minWidth: "170px",
          }}
        >
          Revisar problema
        </button>
      </div>
    </div>
  );
}