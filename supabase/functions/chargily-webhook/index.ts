import { corsHeaders } from "../_shared/cors.ts";
import { verifyChargilySignature } from "../_shared/chargily.ts";
import { createServiceClient } from "../_shared/supabase.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const body = await req.text();
  const signature = req.headers.get("x-chargily-signature") ?? "";
  const headers = Object.fromEntries(req.headers.entries());
  const supabase = createServiceClient();

  let payload: Record<string, unknown> = {};
  try {
    payload = body ? JSON.parse(body) : {};
  } catch {
    payload = {};
  }

  const metadata = (payload.metadata ?? {}) as Record<string, unknown>;
  const paymentId = typeof metadata.payment_id === "string" ? metadata.payment_id : null;
  const eventType = typeof payload.type === "string" ? payload.type : null;

  const { data: webhookLog } = await supabase
    .from("payment_webhook_logs")
    .insert({
      eventType,
      signature,
      headers,
      payload,
      paymentId,
      processingStatus: "received",
    })
    .select()
    .single();

  try {
    const isValid = await verifyChargilySignature(body, signature);
    if (!isValid) {
      await supabase.from("payment_webhook_logs").update({
        processingStatus: "failed",
        notes: "Invalid webhook signature",
      }).eq("id", webhookLog?.id);

      return new Response(JSON.stringify({ error: "Invalid signature" }), {
        status: 401,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (!paymentId) {
      throw new Error("Missing payment_id in webhook metadata");
    }

    const paymentStatus = typeof payload.status === "string" ? payload.status : "";
    const providerPaymentId = typeof payload.id === "string" ? payload.id : null;
    const providerCheckoutId = typeof payload.checkout_id === "string"
      ? payload.checkout_id
      : null;
    const providerReference = typeof payload.reference === "string"
      ? payload.reference
      : null;

    if (["paid", "succeeded", "successful"].includes(paymentStatus)) {
      const { error } = await supabase.rpc("apply_successful_payment", {
        p_payment_id: paymentId,
        p_provider_payment_id: providerPaymentId,
        p_provider_checkout_id: providerCheckoutId,
        p_provider_reference: providerReference,
        p_payload: payload,
      });

      if (error) {
        throw error;
      }
    } else {
      await supabase.from("payments").update({
        status: ["expired", "cancelled"].includes(paymentStatus) ? paymentStatus : "failed",
        failedAt: new Date().toISOString(),
        metadata: payload,
      }).eq("id", paymentId);
    }

    await supabase.from("payment_webhook_logs").update({
      processingStatus: "processed",
      processedAt: new Date().toISOString(),
    }).eq("id", webhookLog?.id);

    return new Response(JSON.stringify({ ok: true }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error) {
    await supabase.from("payment_webhook_logs").update({
      processingStatus: "failed",
      processedAt: new Date().toISOString(),
      notes: error instanceof Error ? error.message : "Unknown error",
    }).eq("id", webhookLog?.id);

    return new Response(JSON.stringify({
      error: error instanceof Error ? error.message : "Unknown error",
    }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
