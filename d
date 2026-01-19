// src/api/problems.js

// Base relativa (mismo host del Front). Ideal para IIS + Reverse Proxy.
// Puedes sobreescribirlo con VITE_API_URL=/api en .env
const API_BASE =
  import.meta?.env?.VITE_API_URL ||
  import.meta?.env?.VITE_API_BASE_URL ||
  import.meta?.env?.VITE_API ||
  window?.API_BASE_URL ||
  "/api";

function buildUrl(path, params = {}) {
  // Si API_BASE es relativo (/api), construimos contra el origin actual
  const base = API_BASE.startsWith("http")
    ? API_BASE
    : `${window.location.origin}${API_BASE}`;

  // 🔥 CLAVE: asegurar que base termine en "/" y que path NO empiece con "/"
  const normalizedBase = base.endsWith("/") ? base : `${base}/`;
  const normalizedPath = String(path).replace(/^\/+/, ""); // quita "/" al inicio

  const url = new URL(normalizedPath, normalizedBase);

  Object.entries(params).forEach(([k, v]) => {
    if (v !== undefined && v !== null && String(v).trim() !== "") {
      url.searchParams.set(k, String(v));
    }
  });

  return url.toString();
}

async function safeReadJson(res) {
  const ct = res.headers.get("content-type") || "";
  if (ct.includes("application/json")) return await res.json();

  const txt = await res.text();
  try {
    return JSON.parse(txt);
  } catch {
    return { data: [], raw: txt };
  }
}

/**
 * GET /api/Problems/latest
 * 👉 Trae TODAS las páginas y devuelve un solo resultado
 */
export async function getLatestProblems({ pageSize = 500, jurisdiction } = {}) {
  let pageNumber = 1;
  let totalPages = 1;
  let totalRecords = 0;
  const allData = [];

  do {
    const url = buildUrl("Problems/latest", { pageNumber, pageSize, jurisdiction });

    const res = await fetch(url, {
      method: "GET",
      headers: { Accept: "application/json, text/plain, */*" },
    });

    if (!res.ok) {
      const txt = await res.text().catch(() => "");
      throw new Error(`Error ${res.status} llamando ${url}\n${txt}`);
    }

    const json = await safeReadJson(res);

    // Caso normal: respuesta paginada
    if (json && Array.isArray(json.data)) {
      totalPages = Number(json.totalPages ?? 1);
      totalRecords = Number(json.totalRecords ?? 0);
      allData.push(...json.data);
    }
    // Fallback: array directo
    else if (Array.isArray(json)) {
      allData.push(...json);
      totalPages = 1;
      totalRecords = allData.length;
    }
    // Cualquier otro caso
    else {
      totalPages = 1;
      totalRecords = allData.length;
    }

    pageNumber++;
  } while (pageNumber <= totalPages);

  return {
    totalRecords: totalRecords || allData.length,
    totalPages: 1,
    pageNumber: 1,
    pageSize: allData.length,
    data: allData,
  };
}
