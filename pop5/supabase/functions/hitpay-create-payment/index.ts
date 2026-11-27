// POST { rental_id, method }  ->  { url, payment_request_id }
// Called by the customer app (C6). Creates a HitPay payment request for the booking
// and saves a pending row in `payments`. The API key never leaves the server.
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
    const user = userData?.user;
    if (!user) return json({ error: 'Please sign in again.' }, 401);

    const { rental_id, method } = await req.json();

    // What the customer chose in the app -> HitPay method id, and the value saved in
    // payments.payment_method (TnG | Bank QR | Cash | Card).
    const CHOICES: Record<string, { hitpay: string; db: 'TnG' | 'Bank QR' | 'Card' }> = {
      TnG: { hitpay: 'touch_n_go', db: 'TnG' },
      DuitNow: { hitpay: 'duitnow', db: 'Bank QR' },
      FPX: { hitpay: 'fpx', db: 'Bank QR' },
      Card: { hitpay: 'card', db: 'Card' },
      'Bank QR': { hitpay: 'duitnow', db: 'Bank QR' }, // older app versions
    };
    // 'Online' (the app's "Pay online" option) is not in the list: HitPay shows every method.
    const known = CHOICES[method];
    const choice = known ?? CHOICES.Card; // saved as Card until the webhook records the real method
    const payMethod = choice.db;

    // RLS: a customer can only read their own rentals.
    const { data: rental } = await userClient
      .from('rentals')
      .select('id, status, total_amount')
      .eq('id', rental_id)
      .maybeSingle();
    if (!rental) return json({ error: 'Booking not found.' }, 404);
    if (rental.status !== 'pending_payment') {
      return json({ error: 'This booking is not waiting for payment.' }, 409);
    }

    const { data: profile } = await admin
      .from('users')
      .select('full_name, email')
      .eq('id', user.id)
      .maybeSingle();

    // ---- HitPay payment request ----
    const body = new URLSearchParams();
    body.set('amount', Number(rental.total_amount).toFixed(2));
    // Sandbox accounts are Singapore accounts (SGD). Use MYR in production.
    body.set('currency', Deno.env.get('HITPAY_CURRENCY') ?? 'SGD');
    body.set('reference_number', rental.id);
    body.set('purpose', `ISYGEAR rental ${rental.id}`);
    if (profile?.email) body.set('email', profile.email);
    if (profile?.full_name) body.set('name', profile.full_name);

    const redirect = Deno.env.get('HITPAY_REDIRECT_URL');
    if (redirect) body.set('redirect_url', redirect);

    // Which methods HitPay shows:
    //  - HITPAY_PAYMENT_METHODS set (e.g. touch_n_go,duitnow,fpx,card): always exactly those.
    //  - HITPAY_RESTRICT_METHODS=true: only the method the customer picked in the app.
    //  - neither: every method enabled on the HitPay account (default, best for the sandbox).
    const override = (Deno.env.get('HITPAY_PAYMENT_METHODS') ?? '')
      .split(',').map((s) => s.trim()).filter(Boolean);
    const restrict = (Deno.env.get('HITPAY_RESTRICT_METHODS') ?? '').toLowerCase() === 'true';
    const methods = override.length ? override : restrict && known ? [choice.hitpay] : [];
    for (const m of methods) body.append('payment_methods[]', m);

    const res = await fetch(`${HITPAY_BASE}/v1/payment-requests`, {
      method: 'POST',
      headers: hitpayHeaders(true),
      body,
    });
    const data = await res.json().catch(() => ({}));
    if (!res.ok || !data?.id || !data?.url) {
      console.error('HitPay create failed', res.status, JSON.stringify(data));
      return json({ error: data?.message ?? 'HitPay could not create the payment.', details: data }, 502);
    }

    // Older unpaid attempts for this booking are no longer valid.
    await admin.from('payments')
      .update({ status: 'failed', failure_reason: 'Replaced by a newer payment attempt' })
      .eq('rental_id', rental.id).eq('payment_type', 'upfront').eq('status', 'pending');

    const { error: insertError } = await admin.from('payments').insert({
      rental_id: rental.id,
      payment_method: payMethod,
      payment_type: 'upfront',
      amount: rental.total_amount,
      status: 'pending',
      gateway_ref: data.id,
    });
    if (insertError) {
      console.error('payments insert failed', insertError.message);
      return json({ error: 'Could not save the payment.' }, 500);
    }

    return json({ url: data.url, payment_request_id: data.id });
  } catch (e) {
    console.error(e);
    return json({ error: String(e instanceof Error ? e.message : e) }, 500);
  }
});
