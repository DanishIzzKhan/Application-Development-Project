// POST { rental_id }  ->  { paid, status }
// Called by the waiting screen (C7) every few seconds. Asks HitPay directly whether the
// payment request is completed, so the app also works if the webhook is slow or not set up yet.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { corsHeaders, json } from '../_shared/cors.ts';
import { HITPAY_BASE, hitpayHeaders } from '../_shared/hitpay.ts';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });

  try {
    const authHeader = req.headers.get('Authorization') ?? '';
    const url = Deno.env.get('SUPABASE_URL')!;
    const anon = Deno.env.get('SUPABASE_ANON_KEY')!;
    const service = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

    const admin = createClient(url, service);
    const userClient = createClient(url, anon, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: userData } = await admin.auth.getUser(authHeader.replace('Bearer ', ''));
    if (!userData?.user) return json({ error: 'Please sign in again.' }, 401);

    const { rental_id } = await req.json();
    const { data: rental } = await userClient
      .from('rentals').select('id, status').eq('id', rental_id).maybeSingle();
    if (!rental) return json({ error: 'Booking not found.' }, 404);

    // Already moved on (paid, started, cancelled ...).
    if (rental.status !== 'pending_payment') {
      return json({
        paid: !['pending_payment', 'cancelled', 'expired'].includes(rental.status),
        status: rental.status,
      });
    }

    const { data: pay } = await admin
      .from('payments')
      .select('gateway_ref')
      .eq('rental_id', rental.id).eq('payment_type', 'upfront').eq('status', 'pending')
      .not('gateway_ref', 'is', null)
      .order('created_at', { ascending: false })
      .limit(1).maybeSingle();
    if (!pay?.gateway_ref) return json({ paid: false, status: 'pending_payment' });

    const res = await fetch(`${HITPAY_BASE}/v1/payment-requests/${pay.gateway_ref}`, {
      headers: hitpayHeaders(),
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok) {
      console.error('HitPay status failed', res.status, JSON.stringify(data));
      return json({ paid: false, status: 'pending_payment' });
    }

    if (data.status === 'completed') {
      const hitpayType = data.payments?.[0]?.payment_type as string | undefined;
      const { data: result, error } = await admin.rpc('complete_gateway_payment', {
        p_gateway_ref: pay.gateway_ref,
        p_gateway_method: hitpayType ?? '',
        p_amount: Number(data.amount),
      });
      if (error) {
        console.error('complete_gateway_payment failed', error.message);
        return json({ paid: false, status: 'pending_payment' });
      }
      return json({ paid: result === 'completed' || result === 'already_completed', status: 'ready' });
    }

    return json({ paid: false, status: 'pending_payment', hitpay_status: data.status });
  } catch (e) {
    console.error(e);
    return json({ error: String(e instanceof Error ? e.message : e) }, 500);
  }
});
