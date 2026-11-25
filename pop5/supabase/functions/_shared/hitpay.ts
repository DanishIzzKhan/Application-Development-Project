// Sandbox: https://api.sandbox.hit-pay.com   Production: https://api.hit-pay.com
export const HITPAY_BASE =
  Deno.env.get('HITPAY_API_BASE') ?? 'https://api.sandbox.hit-pay.com';

export function hitpayHeaders(form = false): Record<string, string> {
  const key = Deno.env.get('HITPAY_API_KEY');
  if (!key) throw new Error('HITPAY_API_KEY is not set.');
  return {
    'X-BUSINESS-API-KEY': key,
    'X-Requested-With': 'XMLHttpRequest',
    ...(form ? { 'Content-Type': 'application/x-www-form-urlencoded' } : {}),
  };
}
