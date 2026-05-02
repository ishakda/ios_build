import { corsHeaders } from "../_shared/cors.ts";
import { createServiceClient } from "../_shared/supabase.ts";
import { createElogistiaOrder, getElogistiaConfig } from "../_shared/elogistia.ts";
import { createYalidineParcels } from "../_shared/yalidine.ts";
import { createZRShipment } from "../_shared/zrexpress.ts";

function splitName(fullName: string) {
  const parts = fullName.trim().split(" ");
  return {
    firstName: parts.slice(0, -1).join(" ") || parts[0] || "Customer",
    lastName: parts[parts.length - 1] || parts[0] || "Sahla",
  };
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });

  try {
    const authHeader = req.headers.get("Authorization");
    if (!authHeader) throw new Error("Missing Authorization header");

    const supabase = createServiceClient();
    const token = authHeader.replace("Bearer ", "");
    const { data: { user }, error: authError } = await supabase.auth.getUser(token);
    if (authError || !user) throw new Error("Invalid user token");

    const { orderId, carrierId } = await req.json();
    if (!orderId || !carrierId) throw new Error("orderId and carrierId are required");

    const { data: order, error: orderError } = await supabase
      .from("orders")
      .select("*, users!orders_buyerId_fkey(*)")
      .eq("id", orderId)
      .single();

    if (orderError || !order) throw new Error("Order not found");

    const shippingAddress = order.shippingAddress as any;
    const nameParts = splitName(shippingAddress.buyerName || order.users?.name || "");

    let responseData: any;
    let trackingNumber: string | undefined;

    if (carrierId === "elogistia") {
       const { apiKey } = getElogistiaConfig();
       responseData = await createElogistiaOrder({
          apiKey,
          name: nameParts.lastName,
          firstname: nameParts.firstName,
          mail: shippingAddress.email || order.users?.email || "",
          phone: shippingAddress.phoneNumber || "",
          address: shippingAddress.address || "",
          commune: shippingAddress.commune || "",
          fraisDeLivraison: order.shippingFee,
          stop_desk: order.deliveryType === "stopdesk" ? 2 : 1,
          wilaya: parseInt(shippingAddress.wilaya) || 16,
          product: "Order #" + order.orderNumber,
          price: order.totalAmount.toString(),
          modeDeLivraison: 1,
          IdCommande: order.orderNumber,
          poids: 1,
       });
       trackingNumber = responseData.success;
    } else if (carrierId === "yalidine") {
       responseData = await createYalidineParcels([{
          order_id: order.orderNumber,
          firstname: nameParts.firstName,
          familyname: nameParts.lastName,
          contact_phone: shippingAddress.phoneNumber,
          address: shippingAddress.address,
          to_wilaya_name: shippingAddress.wilaya,
          to_commune_name: shippingAddress.commune,
          stop_desk: order.deliveryType === "stopdesk" ? 1 : 0,
          is_collection: 0,
          product_list: "Order Items",
          price: order.totalAmount,
       }]);
       // Yalidine returns tracking in response.data[0].tracking
       trackingNumber = responseData.data?.[0]?.tracking;
    } else if (carrierId === "zrexpress") {
       responseData = await createZRShipment({
          consignee_name: shippingAddress.buyerName,
          consignee_phone: shippingAddress.phoneNumber,
          consignee_address: shippingAddress.address,
          consignee_wilaya: shippingAddress.wilaya,
          consignee_commune: shippingAddress.commune,
          type: order.deliveryType === "stopdesk" ? "desk" : "home",
          amount: order.totalAmount,
       });
       trackingNumber = responseData.tracking_number;
    } else {
      throw new Error("Unsupported carrier");
    }

    trackingNumber = trackingNumber || order.orderNumber;

    await supabase.from("shipment_tracking").insert({
      orderId: order.id,
      trackingNumber,
      carrierName: carrierId,
      status: "ready_to_ship",
    });

    await supabase.from("orders").update({
      deliveryStatus: "ready_to_ship",
      status: "Processing"
    }).eq("id", orderId);

    return new Response(JSON.stringify({ success: true, trackingNumber }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
