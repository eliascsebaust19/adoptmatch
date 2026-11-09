import { ApiError } from './http.ts';

export function optional(name: string): string | undefined {
  const value = Deno.env.get(name);
  if (value === undefined) return undefined;
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed : undefined;
}

/**
 * Reads a secret that the feature cannot run without. Missing configuration is a
 * 503, never a silent fallback: a payment that "looks fine" without credentials
 * is worse than an honest error.
 */
export function required(name: string): string {
  const value = optional(name);
  if (!value) {
    throw new ApiError(503, 'NOT_CONFIGURED', `${name} is not configured on this project.`);
  }
  return value;
}

export function supabaseUrl(): string {
  return required('SUPABASE_URL');
}
