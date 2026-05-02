import { corsHeaders } from "../_shared/cors.ts";
import {
  getElogistiaAgencies,
  getElogistiaConfig,
  getElogistiaShippingCosts,
} from "../_shared/elogistia.ts";
import { getYalidineAgencies } from "../_shared/yalidine.ts";
import { getZRAgencies } from "../_shared/zrexpress.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const { carrierId } = await req.json();

    if (carrierId === "elogistia") {
      const { apiKey } = getElogistiaConfig();
      const [shippingCosts, agencies] = await Promise.all([
        getElogistiaShippingCosts(apiKey),
        getElogistiaAgencies(apiKey),
      ]);

      return new Response(JSON.stringify({
        shippingCosts: Array.isArray(shippingCosts.body) ? shippingCosts.body : [],
        agencies: Array.isArray(agencies.body) ? agencies.body : [],
      }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (carrierId === "yalidine") {
      const agenciesResponse = await getYalidineAgencies();
      return new Response(JSON.stringify({
        shippingCosts: [],
        agencies: agenciesResponse.data || [],
      }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (carrierId === "zrexpress") {
      const agenciesResponse = await getZRAgencies();
      return new Response(JSON.stringify({
        shippingCosts: [],
        agencies: agenciesResponse.data || [],
      }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ error: "Unsupported carrier" }), {
      status: 400,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error) {
    return new Response(JSON.stringify({
      error: error instanceof Error ? error.message : "Unknown error",
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
