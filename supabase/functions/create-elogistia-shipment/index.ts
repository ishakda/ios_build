import { corsHeaders } from "../_shared/cors.ts";
import { createElogistiaOrder, getElogistiaConfig } from "../_shared/elogistia.ts";
import { createServiceClient } from "../_shared/supabase.ts";

function splitName(fullName: string) {
  const cleaned = fullName.trim().replace(/\s+/g, " ");
  if (!cleaned) {
    return { firstName: "Customer", lastName: "Sahla" };
  }
  const parts = cleaned.split(" ");
  if (parts.length === 1) {
    return { firstName: parts[0], lastName: parts[0] };
  }
  return {
    firstName: parts.slice(0, -1).join(" "),
    lastName: parts[parts.length - 1] ?? parts[0],
  };
}

function parseWilayaCode(rawWilaya: unknown) {
  const value = `${rawWilaya ?? ""}`.trim();
  const match = value.match(/^(\d{1,2})/);
  if (!match) {
    return 16;
  }
  return Number.parseInt(match[1], 10);
}

function normalizeProductName(value: unknown) {
  return `${value ?? ""}`.replaceAll(",", " ").trim() || "Product";
}

function mapLineItemPrice(item: Record<string, unknown>) {
  const quantity = Number(item.quantity ?? 0);
  const product = item.product && typeof item.product === "object"
    ? item.product as Record<string, unknown>
    : {};
  const basePrice = Number(product.discountPrice ?? product.price ?? 0);
  return Math.max(0, Math.round(basePrice * Math.max(quantity, 1)));
}

function isRecoverableElogistiaResponse(response: Record<string, unknown>) {
  const message = `${response.Message ?? response.message ?? ""}`.trim().toLowerCase();
  if (!message) {
    return true;
  }

  const blockingFragments = [
    "n'existe pas",
    "unauthorized",
    "invalid",
    "erreur",
    "error",
    "obligatoire",
    "incorrect",
  ];

  return !blockingFragments.some((fragment) => message.includes(fragment));
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    console.log("create-elogistia-shipment: request received");
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
    console.log("create-elogistia-shipment: parsed body", { orderId });
    if (!orderId || typeof orderId !== "string") {
      return new Response(JSON.stringify({ error: "orderId is required" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const [{ data: order }, { data: profile }] = await Promise.all([
      supabase.from("orders").select("*").eq("id", orderId).single(),
      supabase.from("users").select("*").eq("id", user.id).single(),
    ]);
    console.log("create-elogistia-shipment: loaded order/profile", {
      hasOrder: Boolean(order),
      userId: user.id,
      role: profile?.role ?? null,
    });

    if (!order) {
      return new Response(JSON.stringify({ error: "Order not found" }), {
        status: 404,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const isAdmin = profile?.role === "admin";
    const sellerIds = Array.isArray(order.sellerIds)
      ? order.sellerIds.map((value: unknown) => `${value}`)
      : [];
    const isSellerParticipant = sellerIds.includes(user.id);
    if (order.buyerId !== user.id && !isAdmin && !isSellerParticipant) {
      return new Response(JSON.stringify({ error: "Forbidden" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const existingShipment = await supabase
      .from("shipment_tracking")
      .select("*")
      .eq("orderId", orderId)
      .eq("carrierName", "elogistia")
      .order("eventAt", { ascending: false })
      .limit(1)
      .maybeSingle();

    if (existingShipment.data?.trackingNumber) {
      console.log("create-elogistia-shipment: reusing existing tracking", {
        orderId,
        trackingNumber: existingShipment.data.trackingNumber,
      });
      return new Response(JSON.stringify({
        trackingNumber: existingShipment.data.trackingNumber,
        reused: true,
      }), {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const shippingAddress = order.shippingAddress && typeof order.shippingAddress === "object"
      ? order.shippingAddress as Record<string, unknown>
      : {};
    const buyerName = `${shippingAddress.buyerName ?? profile?.name ?? ""}`.trim();
    const buyerEmail = `${shippingAddress.email ?? profile?.email ?? ""}`.trim();
    const buyerPhone = `${shippingAddress.phoneNumber ?? profile?.phoneNumber ?? ""}`.trim();
    const commune = `${shippingAddress.commune ?? ""}`.trim();
    const address = `${shippingAddress.address ?? ""}`.trim();
    const wilaya = parseWilayaCode(shippingAddress.wilaya);
    console.log("create-elogistia-shipment: shipping snapshot", {
      buyerName,
      buyerEmail,
      buyerPhone,
      commune,
      address,
      wilaya,
      deliveryType: order.deliveryType,
    });
    if (!buyerPhone || !commune || !address) {
      throw new Error("Order is missing buyer phone or shipping address details");
    }

    const nameParts = splitName(buyerName);
    const items = Array.isArray(order.items) ? order.items as Array<Record<string, unknown>> : [];
    const productNames = items.map((item) => {
      const product = item.product && typeof item.product === "object"
        ? item.product as Record<string, unknown>
        : {};
      const quantity = Number(item.quantity ?? 0);
      const label = normalizeProductName(product.name);
      return quantity > 1 ? `${label} x${quantity}` : label;
    }).join(",");
    const prices = items.map((item) => `${mapLineItemPrice(item)}`).join(",");
    const totalWeight = Math.max(
      1,
      items.reduce((sum, item) => sum + Math.max(1, Number(item.quantity ?? 0)), 0),
    );

    const { apiKey } = getElogistiaConfig();
    console.log("create-elogistia-shipment: calling elogistia");
    const elogistiaResponse = await createElogistiaOrder({
      apiKey,
      name: nameParts.lastName,
      firstname: nameParts.firstName,
      mail: buyerEmail,
      phone: buyerPhone,
      address,
      commune,
      fraisDeLivraison: Number(order.shippingFee ?? 0),
      remarque: `${shippingAddress.addressNote ?? ""}`.trim() || undefined,
      stop_desk: order.deliveryType === "stopdesk" ? 2 : 1,
      wilaya,
      product: productNames || "Product",
      price: prices || `${Math.round(Number(order.totalAmount ?? 0))}`,
      modeDeLivraison: 1,
      IdCommande: `${order.orderNumber ?? order.id}`,
      poids: totalWeight,
    });
    console.log("create-elogistia-shipment: elogistia response", elogistiaResponse);

    const trackingNumber = `${elogistiaResponse.success ?? ""}`.trim();
    const trackingPending = !trackingNumber;
    if (trackingPending && !isRecoverableElogistiaResponse(elogistiaResponse)) {
      throw new Error(`Elogistia did not return a tracking number: ${JSON.stringify(elogistiaResponse)}`);
    }

    const storedTrackingNumber = trackingPending
      ? `${order.orderNumber ?? order.id}`.trim()
      : trackingNumber;

    console.log("create-elogistia-shipment: inserting shipment row", {
      orderId,
      trackingNumber: storedTrackingNumber,
      trackingPending,
    });
    await supabase.from("shipment_tracking").insert({
      orderId,
      trackingNumber: storedTrackingNumber,
      carrierName: "elogistia",
      status: "ready_to_ship",
      notes: trackingPending
        ? "Shipment created in Elogistia; tracking number pending."
        : "Shipment created in Elogistia",
    });

    await supabase.from("orders").update({
      deliveryStatus: "ready_to_ship",
    }).eq("id", orderId);
    console.log("create-elogistia-shipment: order updated", { orderId });

    return new Response(JSON.stringify({
      trackingNumber: storedTrackingNumber,
      trackingPending,
      carrierName: "elogistia",
      payload: elogistiaResponse,
    }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    console.error("create-elogistia-shipment: failed", error);
    return new Response(JSON.stringify({
      error: error instanceof Error ? error.message : "Unknown error",
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
