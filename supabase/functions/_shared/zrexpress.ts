function requireEnv(name: string) {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (!value) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value;
}

export function getZRExpressConfig() {
  return {
    apiKey: requireEnv("ZR_API_KEY"),
    baseUrl: Deno.env.get("ZR_BASE_URL")?.trim() || "https://api.zrexpress.net/api/v1/",
  };
}

async function fetchZR(path: string, method = "GET", body?: unknown) {
  const { apiKey, baseUrl } = getZRExpressConfig();
  const url = new URL(path, baseUrl);

  const response = await fetch(url, {
    method,
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
      "Accept": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });

  const json = await response.json();

  if (!response.ok) {
    throw new Error(`ZR Express request failed: ${JSON.stringify(json)}`);
  }

  return json;
}

export async function getZRWilayas() {
  return await fetchZR("wilayas");
}

export async function getZRCommunes(wilayaId: string) {
  return await fetchZR(`communes/${wilayaId}`);
}

export async function getZRAgencies() {
  return await fetchZR("centers");
}

export async function createZRShipment(data: any) {
  return await fetchZR("shipments", "POST", data);
}
