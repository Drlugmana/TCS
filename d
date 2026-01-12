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

export default function TCSProblems() {
  const [username, setUsername] = useState("");
  const [problems, setProblems] = useState([]);
  const [loading, setLoading] = useState(false);
  const [err, setErr] = useState("");

  // filtros UI (misma idea que ya tenías)
  const [envFilter, setEnvFilter] = useState("ALL"); // PROD | NOPROD | ALL
  const [statusFilter, setStatusFilter] = useState("ALL"); // OPEN | CLOSED | ALL

  // carga inicial + refresh automático
  useEffect(() => {
    let alive = true;

    async function load() {
      setLoading(true);
      setErr("");
      try {
        // Traemos el rango automático de ayer → ahora (backend)
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
    const interval = setInterval(load, 60000); // refresca cada 60s
    return () => {
      alive = false;
      clearInterval(interval);
    };
  }, []);

  // ✅ Solo TCS
  const tcsOnly = useMemo(() => {
    return problems.filter((p) => normalizeJurisdiction(p) === "TCS");
  }, [problems]);

  // ✅ aplica filtros como antes
  const filtered = useMemo(() => {
    return tcsOnly.filter((p) => {
      const env = normalizeEnvironment(p);
      const st = normalizeStatus(p);

      const passEnv =
        envFilter === "ALL" ? true : envFilter === "PROD" ? env === "Productivo" : env !== "Productivo";

      const passStatus = statusFilter === "ALL" ? true : statusFilter === "OPEN" ? st === "OPEN" : st === "CLOSED";

      return passEnv && passStatus;
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

      <div style={{ textAlign: "center", marginBottom: "1rem" }}>
        <div style={{ marginBottom: ".4rem" }}>Usuario:</div>
        <input
          value={username}
          onChange={(e) => setUsername(e.target.value)}
          placeholder="Tu usuario"
          style={{
            padding: "6px 10px",
            borderRadius: 6,
            border: "1px solid #cfcfcf",
            width: 220,
          }}
        />
      </div>

      {/* BOTONES FILTRO (misma idea y estructura) */}
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
          <ProblemCard key={p?.problemId || p?.displayId || idx} problem={p} username={username} />
        ))}
      </div>
    </div>
  );
}
