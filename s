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