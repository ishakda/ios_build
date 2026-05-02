import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

function requireEnv(name: string) {
  const value = Deno.env.get(name)?.trim() ?? "";
  if (!value) {
    throw new Error(`Missing environment variable: ${name}`);
  }
  return value;
}

export function createServiceClient() {
  const supabaseUrl = requireEnv("SUPABASE_URL");
  const serviceRoleKey = requireEnv("SUPABASE_SERVICE_ROLE_KEY");

  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}

export function createUserClient(authHeader: string) {
  const normalizedAuthHeader = authHeader.trim();
  if (!normalizedAuthHeader) {
    throw new Error("Missing Authorization header");
  }

  const supabaseUrl = requireEnv("SUPABASE_URL");
  const anonKey = requireEnv("SUPABASE_ANON_KEY");

  return createClient(supabaseUrl, anonKey, {
    global: {
      headers: {
        Authorization: normalizedAuthHeader,
      },
    },
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });
}
