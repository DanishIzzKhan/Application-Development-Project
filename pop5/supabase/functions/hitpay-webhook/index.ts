// HitPay -> this function (payment_request.completed).
// Deploy WITHOUT jwt verification:  supabase functions deploy hitpay-webhook --no-verify-jwt
// Register in the HitPay dashboard: Developers > Webhook Endpoints, event payment_request.completed.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

async function hmacHex(key: string, message: string): Promise<string> {
  const cryptoKey = await crypto.subtle.importKey(
    'raw', new TextEncoder().encode(key),
    { name: 'HMAC', hash: 'SHA-256' }, false, ['sign'],
  );
  const sig = await crypto.subtle.sign('HMAC', cryptoKey, new TextEncoder().encode(message));
  return Array.from(new Uint8Array(sig)).map((b) => b.toString(16).padStart(2, '0')).join('');
}

function safeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

Deno.serve(async (req) => {
  if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });

  const raw = await req.text(); // the signature is over the raw body
  const signature = (req.headers.get('Hitpay-Signature') ?? '').toLowerCase();
  const salt = Deno.env.get('HITPAY_SALT');
  if (!salt) {
    console.error('HITPAY_SALT is not set');
    return new Response('Server not configured', { status: 500 });
  }

  const expected = await hmacHex(salt, raw);
  if (!safeEqual(expected, signature)) {
    console.error('Invalid HitPay signature');
    return new Response('Invalid signature', { status: 401 });
  }

  let payload: any;
  try {
    payload = JSON.parse(raw);
  } catch {
    return new Response('Bad request', { status: 400 });
  }

  if (payload.status === 'completed' && payload.id) {
    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );
    const hitpayType = payload.payments?.[0]?.payment_type as string | undefined;
    const { data, error } = await admin.rpc('complete_gateway_payment', {
      p_gateway_ref: payload.id,
      p_gateway_method: hitpayType ?? '',
      p_amount: Number(payload.amount),
    });
    if (error) {
      console.error('complete_gateway_payment failed', error.message);
      return new Response('Could not save the payment', { status: 500 }); // HitPay will retry
    }
    console.log('payment', payload.id, '->', data);
  }

  return new Response('OK', { status: 200 });
});
