function requireEnv(name: string) {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (!value) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value;
}

export function getYalidineConfig() {
  return {
    apiId: requireEnv("YALIDINE_API_ID"),
    apiKey: requireEnv("YALIDINE_API_KEY"),
    baseUrl: Deno.env.get("YALIDINE_BASE_URL")?.trim() || "https://api.yalidine.app/v1/",
  };
}

async function fetchYalidine(path: string, method = "GET", body?: unknown) {
  const { apiId, apiKey, baseUrl } = getYalidineConfig();
  const url = new URL(path, baseUrl);

  const response = await fetch(url, {
    method,
    headers: {
      "X-API-ID": apiId,
      "X-API-KEY": apiKey,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const json = await response.json();

  if (!response.ok) {
    throw new Error(`Yalidine request failed: ${JSON.stringify(json)}`);
  }

  return json;
}

export async function getYalidineWilayas() {
  return await fetchYalidine("wilayas");
}

export async function getYalidineCommunes(wilayaId?: string) {
  const path = wilayaId ? `communes?wilaya_id=${wilayaId}` : "communes";
  return await fetchYalidine(path);
}

export async function getYalidineAgencies() {
  return await fetchYalidine("centers");
}

export async function createYalidineParcels(parcels: any[]) {
  return await fetchYalidine("parcels", "POST", parcels);
}
