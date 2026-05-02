import { corsHeaders } from "../_shared/cors.ts";
import { getElogistiaConfig, getElogistiaTracking } from "../_shared/elogistia.ts";
import { createServiceClient } from "../_shared/supabase.ts";

function mapElogistiaStatus(rawStatus: string) {
  const value = rawStatus.toLowerCase();
  if (
    value.includes("livré") ||
    value.includes("livree") ||
    value.includes("livree") ||
    value.includes("remis") ||
    value.includes("delivered")
  ) {
    return "delivered";
  }
  if (
    value.includes("cours livraison") ||
    value.includes("en cours livraison") ||
    value.includes("en livraison") ||
    value.includes("out for delivery") ||
    value.includes("en livraison") ||
    value.includes("livraison")
  ) {
    return "out_for_delivery";
  }
  if (
    value.includes("expédi") ||
    value.includes("exped") ||
    value.includes("dispatch") ||
    value.includes("shipped")
  ) {
    return "shipped";
  }
  if (value.includes("ramass")) {
    return "processing";
  }
  if (
    value.includes("retour remis") ||
    value.includes("confirmation retour") ||
    value.includes("refus client") ||
    value.includes("annuler cause") ||
    value.includes("retour")
  ) {
    return "returned";
  }
  if (
    value.includes("tentative") ||
    value.includes("échec") ||
    value.includes("echec") ||
    value.includes("failed")
  ) {
    return "failed_delivery";
  }
  if (
    value.includes("réception commande") ||
    value.includes("reception commande") ||
    value.includes("ready") ||
    value.includes("préparation") ||
    value.includes("preparation")
  ) {
    return "ready_to_ship";
  }
  return "processing";
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const supabase = createServiceClient();
    const token = authHeader.replace("Bearer ", "");
    const {
      data: { user },
      error: authError,
    } = await supabase.auth.getUser(token);

    if (authError || !user) {
      return new Response(JSON.stringify({ error: "Invalid user token" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { orderId } = await req.json();
    if (!orderId || typeof orderId !== "string") {
      return new Response(JSON.stringify({ error: "orderId is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const [{ data: order }, { data: profile }] = await Promise.all([
      supabase.from("orders").select("*").eq("id", orderId).single(),
      supabase.from("users").select("role").eq("id", user.id).single(),
    ]);

    if (!order) {
      return new Response(JSON.stringify({ error: "Order not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const isParticipant = order.buyerId === user.id ||
      (Array.isArray(order.sellerIds) && order.sellerIds.includes(user.id));
    const isAdmin = profile?.role === "admin";
    if (!isParticipant && !isAdmin) {
      return new Response(JSON.stringify({ error: "Forbidden" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const existing = await supabase
      .from("shipment_tracking")
      .select("*")
      .eq("orderId", orderId)
      .eq("carrierName", "elogistia")
      .order("eventAt", { ascending: false })
      .limit(1)
      .maybeSingle();

    const trackingNumber = `${existing.data?.trackingNumber ?? ""}`.trim();
    if (!trackingNumber) {
      return new Response(JSON.stringify({ error: "No Elogistia tracking found for order" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const { apiKey } = getElogistiaConfig();
    const trackingResponse = await getElogistiaTracking(apiKey, trackingNumber);
    const history = Array.isArray(trackingResponse.body)
      ? trackingResponse.body as Array<Record<string, unknown>>
      : [];

    await supabase.from("shipment_tracking")
      .delete()
      .eq("orderId", orderId)
      .eq("carrierName", "elogistia");

    if (history.length == 0) {
      await supabase.from("shipment_tracking").insert({
        orderId,
        carrierName: "elogistia",
        trackingNumber,
        status: "processing",
        notes: "No tracking history returned yet",
      });
      return new Response(JSON.stringify({ trackingNumber, itemCount: 0 }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const rows = history.map((event) => {
      const statusText = `${event["Statut"] ?? event.logtext ?? ""}`.trim();
      const eventAtRaw = `${event.Date ?? ""}`.trim();
      const eventAt = eventAtRaw ? new Date(eventAtRaw.replace(" ", "T")).toISOString() : new Date().toISOString();
      return {
        orderId,
        carrierName: "elogistia",
        trackingNumber,
        status: mapElogistiaStatus(statusText),
        notes: `${event.logtext ?? statusText}`.trim() || statusText,
        eventAt,
      };
    });

    await supabase.from("shipment_tracking").insert(rows);

    const latest = rows[rows.length - 1];
    await supabase.from("orders").update({
      deliveryStatus: latest.status,
    }).eq("id", orderId);

    return new Response(JSON.stringify({
      trackingNumber,
      itemCount: rows.length,
      latestStatus: latest.status,
    }), {
      status: 200,
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
