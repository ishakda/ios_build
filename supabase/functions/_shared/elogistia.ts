function requireEnv(name: string) {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (!value) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value;
}

export function getElogistiaConfig() {
  return {
    apiKey: requireEnv("ELOGISTIA_API_KEY"),
    baseUrl: Deno.env.get("ELOGISTIA_BASE_URL")?.trim() || "https://api.elogistia.com",
  };
}

function buildUrl(
  baseUrl: string,
  path: string,
  params: Record<string, string | number | undefined | null>,
) {
  const url = new URL(path, baseUrl.endsWith("/") ? baseUrl : `${baseUrl}/`);
  for (const [key, value] of Object.entries(params)) {
    if (value === undefined || value === null || `${value}`.trim() === "") {
      continue;
    }
    url.searchParams.set(key, `${value}`);
  }
  return url;
}

async function fetchJson(url: URL, method = "GET") {
  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 15000);

  let response: Response;
  try {
    response = await fetch(url, { method, signal: controller.signal });
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      throw new Error(`Elogistia request timed out after 15 seconds: ${url.pathname}`);
    }
    throw error;
  } finally {
    clearTimeout(timeoutId);
  }

  const text = await response.text();

  let json: unknown;
  try {
    json = text ? JSON.parse(text) : null;
  } catch (_) {
    json = text;
  }

  if (!response.ok) {
    throw new Error(
      `Elogistia request failed (${response.status}): ${
        typeof json === "string" ? json : JSON.stringify(json)
      }`,
    );
  }

  return json;
}

export async function createElogistiaOrder(params: {
  apiKey: string;
  name: string;
  firstname: string;
  mail: string;
  phone: string;
  address: string;
  commune: string;
  fraisDeLivraison?: number;
  remarque?: string;
  stop_desk: 1 | 2;
  wilaya: number;
  product: string;
  price: string;
  modeDeLivraison: 1 | 4;
  exchangeName?: string;
  IdCommande: string;
  poids: number;
}) {
  const { baseUrl } = getElogistiaConfig();
  const url = buildUrl(baseUrl, "insertCommande/", params);
  return await fetchJson(url, "POST") as {
    success?: string;
    [key: string]: unknown;
  };
}

export async function getElogistiaTracking(apiKey: string, tracking: string) {
  const { baseUrl } = getElogistiaConfig();
  const url = buildUrl(baseUrl, "getTracking/", { apiKey, tracking });
  return await fetchJson(url) as {
    body?: Array<Record<string, unknown>>;
    itemCount?: number;
    [key: string]: unknown;
  };
}

export async function getElogistiaShippingCosts(apiKey: string) {
  const { baseUrl } = getElogistiaConfig();
  const url = buildUrl(baseUrl, "getShippingCost/", { key: apiKey });
  return await fetchJson(url) as {
    body?: Array<Record<string, unknown>>;
    itemCount?: number;
    [key: string]: unknown;
  };
}

export async function getElogistiaAgencies(apiKey: string) {
  const { baseUrl } = getElogistiaConfig();
  const url = buildUrl(baseUrl, "getAgences/", { key: apiKey });
  return await fetchJson(url) as {
    body?: Array<Record<string, unknown>>;
    itemCount?: number;
    [key: string]: unknown;
  };
}
