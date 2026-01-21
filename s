// src/pages/TCSProblems.jsx
import React, { useEffect, useMemo, useState } from "react";
import ProblemCard from "../components/ProblemCard";
import { getLatestProblems } from "../api/problems";

// Helpers para normalizar
function norm(s) {
  return String(s || "")
    .trim()
    .toUpperCase()
    .replace(/\s+/g, "");
}

function normalizeStatus(p) {
  const raw = p?.status ?? p?.Status ?? p?.problemStatus ?? p?.problemState ?? "";
  const s = String(raw || "").trim().toUpperCase();
  if (s.includes("OPEN")) return "OPEN";
  if (s.includes("CLOSED") || s.includes("RESOLVED")) return "CLOSED";
  return p?.endTime ? "CLOSED" : "OPEN";
}

function normalizeEnvironment(p) {
  const raw = p?.environment ?? p?.Environment ?? "";
  const s = norm(raw);
  if (s === "PRODUCTIVO") return "Productivo";
  if (s.includes("NOPRODUCTIVO") || s.includes("NO")) return "NoProductivo";
  return raw || "";
}

function normalizeJurisdiction(p) {
  return norm(p?.jurisdiction ?? p?.Jurisdiction ?? "");
}

// ✅ NUEVO: helpers para ordenar
function getStartDateMs(p) {
  const raw = p?.startTime ?? p?.StartTime;
  const d = raw ? new Date(raw) : null;
  const ms = d && !isNaN(d.getTime()) ? d.getTime() : 0;
  return ms;
}

// Comentarios: detecta vacío (null/undefined/"") o lista vacía
function hasBlankComments(p) {
  // 1) Si backend ya manda un campo plano tipo "comentarios"
  const flat = p?.comentarios ?? p?.Comentarios ?? p?.commentsText ?? p?.CommentsText;
  if (flat !== undefined && flat !== null) {
    return String(flat).trim() === "";
  }

  // 2) Si manda recentComments.comments
  const arr =
    p?.recentComments?.comments ??
    p?.RecentComments?.comments ??
    p?.recentComments ??
    p?.RecentComments;

  if (!arr) return true;
  if (Array.isArray(arr)) return arr.length === 0;

  // Si viene objeto con comments adentro
  if (Array.isArray(arr?.comments)) return arr.comments.length === 0;

  return true;
}

// Severidad BIA (criticidad): S1..S4 (si no existe, lo manda al final)
function getBiaRank(p) {
  const c = String(p?.criticidad ?? p?.Criticidad ?? p?.bia ?? p?.Bia ?? "")
    .trim()
    .toUpperCase();

  if (c === "S1") return 1;
  if (c === "S2") return 2;
  if (c === "S3") return 3;
  if (c === "S4") return 4;

  // Si viene "S1 - ..." o algo parecido
  if (c.includes("S1")) return 1;
  if (c.includes("S2")) return 2;
  if (c.includes("S3")) return 3;
  if (c.includes("S4")) return 4;

  return 99;
}

// clave estable de desempate
function getStableKey(p) {
  return String(p?.problemId ?? p?.ProblemId ?? p?.displayId ?? p?.DisplayId ?? "").trim();
}

// ✅ NUEVO: detectar "verde" (tiene comentarios NO vacíos)
function hasComments(p) {
  const flat = p?.comentarios ?? p?.Comentarios ?? p?.commentsText ?? p?.CommentsText;
  if (flat !== undefined && flat !== null) return String(flat).trim().length > 0;

  const arr =
    p?.recentComments?.comments ??
    p?.RecentComments?.comments ??
    p?.recentComments ??
    p?.RecentComments;

  if (!arr) return false;
  if (Array.isArray(arr)) return arr.length > 0;
  if (Array.isArray(arr?.comments)) return arr.comments.length > 0;

  return false;
}

export default function TCSProblems() {
  const ALWAYS_USERNAME = "SISTEMA";

  const [problems, setProblems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState("");

  const [envFilter, setEnvFilter] = useState("ALL");
  const [statusFilter, setStatusFilter] = useState("ALL");

  useEffect(() => {
    let alive = true;

    async function load() {
      setLoading(true);
      setErr("");
      try {
        // Traemos el latest (tu api trae todo por paginación interna en problems.js)
        const res = await getLatestProblems({ pageNumber: 1, pageSize: 1000 });
        if (!alive) return;
        setProblems(Array.isArray(res?.data) ? res.data : []);
      } catch (e) {
        if (!alive) return;
        setErr(e?.message || "Error consultando problemas");
        setProblems([]);
      } finally {
        if (alive) setLoading(false);
      }
    }

    load();
    const interval = setInterval(load, 60000);
    return () => {
      alive = false;
      clearInterval(interval);
    };
  }, []);

  // Solo TCS
  const tcsOnly = useMemo(() => {
    return problems.filter((p) => normalizeJurisdiction(p) === "TCS");
  }, [problems]);

  // ✅ filtros + ✅ ORDEN
  const filtered = useMemo(() => {
    const base = tcsOnly.filter((p) => {
      const env = normalizeEnvironment(p);
      const st = normalizeStatus(p);

      const passEnv =
        envFilter === "ALL" ? true : envFilter === "PROD" ? env === "Productivo" : env !== "Productivo";

      const passStatus = statusFilter === "ALL" ? true : statusFilter === "OPEN" ? st === "OPEN" : st === "CLOSED";

      return passEnv && passStatus;
    });

    // ✅ Orden final:
    // 1) NO verdes primero (sin comentarios), verdes al final
    // 2) Dentro de CADA grupo: Criticidad S1 → S4
    // 3) Desempate estable por ID (para no “bailar” la lista)
    return [...base].sort((a, b) => {
      const aGreen = hasComments(a) ? 1 : 0;
      const bGreen = hasComments(b) ? 1 : 0;
      if (aGreen !== bGreen) return aGreen - bGreen;

      const aRank = getBiaRank(a);
      const bRank = getBiaRank(b);
      if (aRank !== bRank) return aRank - bRank;

      const ak = getStableKey(a);
      const bk = getStableKey(b);
      return ak.localeCompare(bk);
    });
  }, [tcsOnly, envFilter, statusFilter]);

  // contadores
  const counts = useMemo(() => {
    const base = tcsOnly;
    const prod = base.filter((p) => normalizeEnvironment(p) === "Productivo").length;
    const noprod = base.length - prod;
    const open = base.filter((p) => normalizeStatus(p) === "OPEN").length;
    const closed = base.filter((p) => normalizeStatus(p) === "CLOSED").length;
    return { total: base.length, prod, noprod, open, closed };
  }, [tcsOnly]);

  return (
    <div style={{ padding: "1rem 0" }}>
      <h1 style={{ textAlign: "center", margin: "0 0 0.5rem 0" }}>
        Problemas TCS ({filtered.length})
      </h1>

      <div style={{ display: "flex", justifyContent: "center", gap: "10px", flexWrap: "wrap", marginBottom: "1rem" }}>
        <button
          onClick={() => setEnvFilter("PROD")}
          style={{
            padding: "6px 14px",
            borderRadius: 16,
            border: "1px solid #cfcfcf",
            background: envFilter === "PROD" ? "#3b82f6" : "#e5e7eb",
            color: envFilter === "PROD" ? "#fff" : "#111",
            fontWeight: "bold",
            cursor: "pointer",
          }}
        >
          Productivo ({counts.prod})
        </button>

        <button
          onClick={() => setEnvFilter("NOPROD")}
          style={{
            padding: "6px 14px",
            borderRadius: 16,
            border: "1px solid #cfcfcf",
            background: envFilter === "NOPROD" ? "#9ca3af" : "#e5e7eb",
            color: "#111",
            fontWeight: "bold",
            cursor: "pointer",
          }}
        >
          No Productivo ({counts.noprod})
        </button>

        <button
          onClick={() => setStatusFilter("OPEN")}
          style={{
            padding: "6px 14px",
            borderRadius: 16,
            border: "1px solid #cfcfcf",
            background: statusFilter === "OPEN" ? "#f59e0b" : "#e5e7eb",
            color: "#111",
            fontWeight: "bold",
            cursor: "pointer",
          }}
        >
          Abiertas ({counts.open})
        </button>

        <button
          onClick={() => setStatusFilter("CLOSED")}
          style={{
            padding: "6px 14px",
            borderRadius: 16,
            border: "1px solid #cfcfcf",
            background: statusFilter === "CLOSED" ? "#10b981" : "#e5e7eb",
            color: "#111",
            fontWeight: "bold",
            cursor: "pointer",
          }}
        >
          Cerradas ({counts.closed})
        </button>

        <button
          onClick={() => {
            setEnvFilter("ALL");
            setStatusFilter("ALL");
          }}
          style={{
            padding: "6px 14px",
            borderRadius: 16,
            border: "1px solid #cfcfcf",
            background: envFilter === "ALL" && statusFilter === "ALL" ? "#d1d5db" : "#e5e7eb",
            color: "#111",
            fontWeight: "bold",
            cursor: "pointer",
          }}
        >
          Todos
        </button>
      </div>

      {loading && <div style={{ textAlign: "center" }}>Cargando...</div>}
      {!!err && <div style={{ textAlign: "center", color: "red" }}>{err}</div>}

      <div style={{ maxWidth: 980, margin: "0 auto", padding: "0 12px" }}>
        {filtered.map((p, idx) => (
          <ProblemCard
            key={p?.problemId || p?.displayId || idx}
            problem={p}
            username={ALWAYS_USERNAME}
          />
        ))}
      </div>
    </div>
  );
}

-------------------------------


// src/pages/OtherProblems.jsx
import React, { useEffect, useMemo, useState } from "react";
import ProblemCard from "../components/ProblemCard";
import { getLatestProblems } from "../api/problems";

function norm(s) {
  return String(s || "")
    .trim()
    .toUpperCase()
    .replace(/\s+/g, "");
}

function normalizeStatus(p) {
  const raw = p?.status ?? p?.Status ?? p?.problemStatus ?? p?.problemState ?? "";
  const s = String(raw || "").trim().toUpperCase();
  if (s.includes("OPEN")) return "OPEN";
  if (s.includes("CLOSED") || s.includes("RESOLVED")) return "CLOSED";
  return p?.endTime ? "CLOSED" : "OPEN";
}

function normalizeEnvironment(p) {
  const raw = p?.environment ?? p?.Environment ?? "";
  const s = norm(raw);
  if (s === "PRODUCTIVO") return "Productivo";
  if (s.includes("NOPRODUCTIVO") || s.includes("NO")) return "NoProductivo";
  return raw || "";
}

function normalizeJurisdiction(p) {
  return norm(p?.jurisdiction ?? p?.Jurisdiction ?? "");
}

// ✅ helpers orden
function getStartDateMs(p) {
  const raw = p?.startTime ?? p?.StartTime;
  const d = raw ? new Date(raw) : null;
  const ms = d && !isNaN(d.getTime()) ? d.getTime() : 0;
  return ms;
}

function hasBlankComments(p) {
  const flat = p?.comentarios ?? p?.Comentarios ?? p?.commentsText ?? p?.CommentsText;
  if (flat !== undefined && flat !== null) {
    return String(flat).trim() === "";
  }

  const arr =
    p?.recentComments?.comments ??
    p?.RecentComments?.comments ??
    p?.recentComments ??
    p?.RecentComments;

  if (!arr) return true;
  if (Array.isArray(arr)) return arr.length === 0;
  if (Array.isArray(arr?.comments)) return arr.comments.length === 0;

  return true;
}

function getBiaRank(p) {
  const c = String(p?.criticidad ?? p?.Criticidad ?? p?.bia ?? p?.Bia ?? "")
    .trim()
    .toUpperCase();

  if (c === "S1") return 1;
  if (c === "S2") return 2;
  if (c === "S3") return 3;
  if (c === "S4") return 4;

  if (c.includes("S1")) return 1;
  if (c.includes("S2")) return 2;
  if (c.includes("S3")) return 3;
  if (c.includes("S4")) return 4;

  return 99;
}

function getStableKey(p) {
  return String(p?.problemId ?? p?.ProblemId ?? p?.displayId ?? p?.DisplayId ?? "").trim();
}

// ✅ NUEVO: detectar "verde" (tiene comentarios NO vacíos)
function hasComments(p) {
  const flat = p?.comentarios ?? p?.Comentarios ?? p?.commentsText ?? p?.CommentsText;
  if (flat !== undefined && flat !== null) return String(flat).trim().length > 0;

  const arr =
    p?.recentComments?.comments ??
    p?.RecentComments?.comments ??
    p?.recentComments ??
    p?.RecentComments;

  if (!arr) return false;
  if (Array.isArray(arr)) return arr.length > 0;
  if (Array.isArray(arr?.comments)) return arr.comments.length > 0;

  return false;
}

export default function OtherProblems() {
  const ALWAYS_USERNAME = "SISTEMA";

  const [problems, setProblems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState("");

  const [envFilter, setEnvFilter] = useState("ALL");
  const [statusFilter, setStatusFilter] = useState("ALL");

  useEffect(() => {
    let alive = true;

    async function load() {
      setLoading(true);
      setErr("");
      try {
        const res = await getLatestProblems({ pageNumber: 1, pageSize: 1000 });
        if (!alive) return;
        setProblems(Array.isArray(res?.data) ? res.data : []);
      } catch (e) {
        if (!alive) return;
        setErr(e?.message || "Error consultando problemas");
        setProblems([]);
      } finally {
        if (alive) setLoading(false);
      }
    }

    load();
    const interval = setInterval(load, 60000);
    return () => {
      alive = false;
      clearInterval(interval);
    };
  }, []);

  // Todo lo que NO sea TCS
  const otherOnly = useMemo(() => {
    return problems.filter((p) => normalizeJurisdiction(p) !== "TCS");
  }, [problems]);

  const filtered = useMemo(() => {
    const base = otherOnly.filter((p) => {
      const env = normalizeEnvironment(p);
      const st = normalizeStatus(p);

      const passEnv =
        envFilter === "ALL" ? true : envFilter === "PROD" ? env === "Productivo" : env !== "Productivo";

      const passStatus = statusFilter === "ALL" ? true : statusFilter === "OPEN" ? st === "OPEN" : st === "CLOSED";

      return passEnv && passStatus;
    });

    // ✅ Orden final:
    // 1) NO verdes primero (sin comentarios), verdes al final
    // 2) Dentro de CADA grupo: Criticidad S1 → S4
    // 3) Desempate estable por ID
    return [...base].sort((a, b) => {
      const aGreen = hasComments(a) ? 1 : 0;
      const bGreen = hasComments(b) ? 1 : 0;
      if (aGreen !== bGreen) return aGreen - bGreen;

      const aRank = getBiaRank(a);
      const bRank = getBiaRank(b);
      if (aRank !== bRank) return aRank - bRank;

      const ak = getStableKey(a);
      const bk = getStableKey(b);
      return ak.localeCompare(bk);
    });
  }, [otherOnly, envFilter, statusFilter]);

  const counts = useMemo(() => {
    const base = otherOnly;
    const prod = base.filter((p) => normalizeEnvironment(p) === "Productivo").length;
    const noprod = base.length - prod;
    const open = base.filter((p) => normalizeStatus(p) === "OPEN").length;
    const closed = base.filter((p) => normalizeStatus(p) === "CLOSED").length;

    return { total: base.length, prod, noprod, open, closed };
  }, [otherOnly]);

  return (
    <div style={{ padding: "1rem 0" }}>
      <h1 style={{ textAlign: "center", margin: "0 0 0.5rem 0" }}>
        Problemas Otros ({filtered.length})
      </h1>

      <div style={{ display: "flex", justifyContent: "center", gap: "10px", flexWrap: "wrap", marginBottom: "1rem" }}>
        <button
          onClick={() => setEnvFilter("PROD")}
          style={{
            padding: "6px 14px",
            borderRadius: 16,
            border: "1px solid #cfcfcf",
            background: envFilter === "PROD" ? "#3b82f6" : "#e5e7eb",
            color: envFilter === "PROD" ? "#fff" : "#111",
            fontWeight: "bold",
            cursor: "pointer",
          }}
        >
          Productivo ({counts.prod})
        </button>

        <button
          onClick={() => setEnvFilter("NOPROD")}
          style={{
            padding: "6px 14px",
            borderRadius: 16,
            border: "1px solid #cfcfcf",
            background: envFilter === "NOPROD" ? "#9ca3af" : "#e5e7eb",
            color: "#111",
            fontWeight: "bold",
            cursor: "pointer",
          }}
        >
          No Productivo ({counts.noprod})
        </button>

        <button
          onClick={() => setStatusFilter("OPEN")}
          style={{
            padding: "6px 14px",
            borderRadius: 16,
            border: "1px solid #cfcfcf",
            background: statusFilter === "OPEN" ? "#f59e0b" : "#e5e7eb",
            color: "#111",
            fontWeight: "bold",
            cursor: "pointer",
          }}
        >
          Abiertas ({counts.open})
        </button>

        <button
          onClick={() => setStatusFilter("CLOSED")}
          style={{
            padding: "6px 14px",
            borderRadius: 16,
            border: "1px solid #cfcfcf",
            background: statusFilter === "CLOSED" ? "#10b981" : "#e5e7eb",
            color: "#111",
            fontWeight: "bold",
            cursor: "pointer",
          }}
        >
          Cerradas ({counts.closed})
        </button>

        <button
          onClick={() => {
            setEnvFilter("ALL");
            setStatusFilter("ALL");
          }}
          style={{
            padding: "6px 14px",
            borderRadius: 16,
            border: "1px solid #cfcfcf",
            background: envFilter === "ALL" && statusFilter === "ALL" ? "#d1d5db" : "#e5e7eb",
            color: "#111",
            fontWeight: "bold",
            cursor: "pointer",
          }}
        >
          Todos
        </button>
      </div>

      {loading && <div style={{ textAlign: "center" }}>Cargando...</div>}
      {!!err && <div style={{ textAlign: "center", color: "red" }}>{err}</div>}

      <div style={{ maxWidth: 980, margin: "0 auto", padding: "0 12px" }}>
        {filtered.map((p, idx) => (
          <ProblemCard
            key={p?.problemId || p?.displayId || idx}
            problem={p}
            username={ALWAYS_USERNAME}
          />
        ))}
      </div>
    </div>
  );
}

---------------------


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

// Limpia texto para que no se repita "COMENTARIO"/"DETALLE"
function normalizeOneLineText(input, removeWords = []) {
  let t = String(input ?? "").trim();
  if (!t) return "";

  // Quitar palabras repetidas tipo "COMENTARIO" o "DETALLE" (al inicio o en líneas)
  for (const w of removeWords) {
    const reLine = new RegExp(`(^|\\n)\\s*${w}\\s*(\\n|$)`, "gi");
    t = t.replace(reLine, "\n");
    const reInline = new RegExp(`\\b${w}\\b\\s*[-:]*\\s*`, "gi");
    t = t.replace(reInline, "");
  }

  // Convertir saltos de línea / tabs en separador " - "
  t = t.replace(/\r\n/g, "\n").replace(/\r/g, "\n");
  t = t.replace(/\t+/g, " ");
  t = t.replace(/\n+/g, " - ");

  // Limpiar espacios
  t = t.replace(/\s{2,}/g, " ").trim();

  // Si quedaron separadores duplicados
  t = t.replace(/\s*-\s*-\s*/g, " - ").trim();

  return t;
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

  // soporta startTime / StartTime
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

  // Botón SIEMPRE funcional (solo se deshabilita si no hay URL válida)
  const tenant = pick(problem, "tenant", "Tenant") || "";
  const problemId = pick(problem, "problemId", "ProblemId", "displayId", "DisplayId") || "";

  const dynatraceUrl =
    tenant && problemId
      ? `https://${tenant}.live.dynatrace.com/#problems/problemdetails;pid=${problemId}`
      : "#";

  const environmentRaw = pick(problem, "environment", "Environment") || "";
  const environment = normalizeEnvironment(environmentRaw);

  // ✅ Comentarios y Detalle (desde latest)
  const rawComments = pick(problem, "comentarios", "Comentarios", "commentsText", "CommentsText", "comments", "Comments");
  const rawDetail = pick(
    problem,
    "detalleDeProblema",
    "DetalleDeProblema",
    "detalleProblema",
    "DetalleProblema",
    "detalle",
    "Detalle"
  );

  const commentsText = useMemo(
    () => normalizeOneLineText(rawComments, ["COMENTARIO", "COMENTARIOS"]),
    [rawComments]
  );

  const detailText = useMemo(
    () => normalizeOneLineText(rawDetail, ["DETALLE", "DETALLEDEPROBLEMA", "DETALLE DE PROBLEMA"]),
    [rawDetail]
  );

  // Si ya tiene comentarios, la tarjeta se pone verde
  const hasComments = useMemo(() => String(commentsText || "").trim().length > 0, [commentsText]);
  const cardBg = hasComments ? "#b7f7c0" : bgColor; // verde claro

  // Ajustes visuales
  const TITLE_FS = "1.15rem";
  const TEXT_FS = ".95rem";
  const ICON_SIZE = 70;

  // ✅ NUEVO: estilo de resaltado para Comentarios/Detalle (sin cambiar lógica)
  const HIGHLIGHT_BOX = {
    display: "block",
    marginTop: ".2rem",
    padding: ".35rem .5rem",
    borderRadius: "8px",
    border: "1px solid rgba(0,0,0,.12)",
    background: "rgba(255,255,255,.55)",

    // ✅ CLAVE: mostrar TODO el texto (sin ellipsis) y que haga wrap
    whiteSpace: "normal",
    overflow: "visible",
    textOverflow: "clip",
    wordBreak: "break-word",
    overflowWrap: "anywhere",
    lineHeight: 1.25,
  };

  return (
    <div
      style={{
        display: "flex",
        justifyContent: "space-between",
        alignItems: "center",
        borderRadius: "12px",
        padding: ".6rem 1rem",
        marginBottom: ".6rem",
        backgroundColor: cardBg,
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

        {/* ✅ Comentarios: resaltado + texto completo */}
        <p style={{ fontSize: TEXT_FS, margin: ".25rem 0" }}>
          <strong>Comentarios:</strong>
          <span title={commentsText || ""} style={HIGHLIGHT_BOX}>
            {commentsText || "--"}
          </span>
        </p>

        {/* ✅ Detalle: resaltado + texto completo */}
        <p style={{ fontSize: TEXT_FS, margin: ".25rem 0" }}>
          <strong>Detalle de Problema:</strong>
          <span title={detailText || ""} style={HIGHLIGHT_BOX}>
            {detailText || "--"}
          </span>
        </p>
      </div>

      {/* CENTRO: ICONOS */}
      <div
        style={{
          display: "flex",
          justifyContent: "center",
          alignItems: "center",
          gap: ".6rem",
          flexShrink: 0,
          minWidth: "170px",
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
