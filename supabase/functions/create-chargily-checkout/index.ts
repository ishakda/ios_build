import { corsHeaders } from "../_shared/cors.ts";
import { createChargilyCheckout, getChargilyConfig } from "../_shared/chargily.ts";
import { createServiceClient, createUserClient } from "../_shared/supabase.ts";

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
    const userSupabase = createUserClient(authHeader);
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

    const { data: paymentId, error: paymentCreateError } = await userSupabase.rpc(
      "create_marketplace_payment",
      {
        p_order_id: orderId,
        p_idempotency_key: crypto.randomUUID(),
      },
    );

    if (paymentCreateError || !paymentId) {
      throw paymentCreateError ?? new Error("Failed to create payment");
    }

    const [{ data: payment }, { data: order }] = await Promise.all([
      supabase.from("payments").select("*").eq("id", paymentId).single(),
      supabase.from("orders").select("*").eq("id", orderId).single(),
    ]);

    if (!payment || !order) {
      throw new Error("Payment context not found");
    }

    if (order.buyerId !== user.id) {
      return new Response(JSON.stringify({ error: "Order does not belong to the user" }), {
        status: 403,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    const existingCheckoutUrl = payment.providerCheckoutUrl as string | null;
    const existingCheckoutId = payment.providerCheckoutId as string | null;
    const existingReference = payment.providerReference as string | null;
    const paymentStatus = payment.status as string;
    const expiresAtRaw = payment.expiresAt as string | null;
    if (
      existingCheckoutUrl &&
      (paymentStatus === "checkout_created" || paymentStatus === "processing")
    ) {
      if (!expiresAtRaw || new Date(expiresAtRaw).getTime() > Date.now()) {
        return new Response(JSON.stringify({
          paymentId: payment.id,
          checkoutId: existingCheckoutId,
          checkoutUrl: existingCheckoutUrl,
          reference: existingReference,
          reused: true,
        }), {
          status: 200,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }
    }

    const config = getChargilyConfig();
    const successUrl = config.appBaseUrl
      ? `${config.appBaseUrl}/payment/success?orderId=${orderId}`
      : undefined;
    const failureUrl = config.appBaseUrl
      ? `${config.appBaseUrl}/payment/failure?orderId=${orderId}`
      : undefined;

    const checkout = await createChargilyCheckout({
      amount: payment.amount,
      currency: payment.currency,
      success_url: successUrl,
      failure_url: failureUrl,
      metadata: {
        payment_id: payment.id,
        order_id: orderId,
        buyer_id: user.id,
      },
      description: `Sahla order ${order.orderNumber ?? order.id}`,
    });

    const providerCheckoutId = checkout.id ?? checkout.checkout_id ?? null;
    const providerCheckoutUrl = checkout.checkout_url ?? checkout.url ?? null;
    const providerReference = checkout.reference ?? null;

    const { error: paymentUpdateError } = await supabase
      .from("payments")
      .update({
        status: "checkout_created",
        providerCheckoutId,
        providerCheckoutUrl,
        providerReference,
        expiresAt: checkout.expires_at ?? null,
        metadata: {
          ...(payment.metadata ?? {}),
          checkout,
        },
      })
      .eq("id", payment.id);

    if (paymentUpdateError) {
      throw paymentUpdateError;
    }

    await supabase.from("orders").update({
      paymentStatus: "checkout_created",
      chargilyCheckoutId: providerCheckoutId,
      paymentReference: providerReference,
      paymentMethod: "chargily",
    }).eq("id", orderId);

    return new Response(JSON.stringify({
      paymentId: payment.id,
      checkoutId: providerCheckoutId,
      checkoutUrl: providerCheckoutUrl,
      reference: providerReference,
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
