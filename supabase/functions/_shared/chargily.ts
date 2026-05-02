const defaultBaseUrl = "https://pay.chargily.dz/api";

export function getChargilyConfig() {
  const secretKey = Deno.env.get("CHARGILY_SECRET_KEY") ?? "";
  const webhookSecret = Deno.env.get("CHARGILY_WEBHOOK_SECRET") ?? "";
  const apiBaseUrl = Deno.env.get("CHARGILY_API_BASE_URL") ?? defaultBaseUrl;
  const appBaseUrl = Deno.env.get("APP_BASE_URL") ?? "";

  if (!secretKey) {
    throw new Error("Missing CHARGILY_SECRET_KEY");
  }

  return {
    secretKey,
    webhookSecret,
    apiBaseUrl,
    appBaseUrl,
  };
}

export async function createChargilyCheckout(payload: Record<string, unknown>) {
  const config = getChargilyConfig();

  const response = await fetch(`${config.apiBaseUrl}/checkouts`, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${config.secretKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(payload),
  });

  const data = await response.json().catch(() => ({}));

  if (!response.ok) {
    throw new Error(`Chargily checkout error: ${JSON.stringify(data)}`);
  }

  return data;
}

export async function verifyChargilySignature(
  requestBody: string,
  signature: string,
) {
  const { webhookSecret } = getChargilyConfig();

  if (!webhookSecret) {
    return false;
  }

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(webhookSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const digest = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(requestBody),
  );

  const expected = Array.from(new Uint8Array(digest))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  return expected === signature;
}
