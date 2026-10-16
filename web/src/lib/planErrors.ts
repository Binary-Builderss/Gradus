/** Un tetto del piano raggiunto su template o progressioni: il database risponde `<tipo>_limit_reached` con il tetto nel hint. */
export type ContentLimit = { kind: 'mesocycle_templates' | 'progression_presets'; limit: number | null }

export function contentLimitReached(error: unknown): ContentLimit | null {
  const { message, hint } = (error ?? {}) as { message?: string; hint?: string }
  for (const kind of ['mesocycle_templates', 'progression_presets'] as const) {
    if (message?.includes(`${kind}_limit_reached`)) {
      const limit = Number(hint)
      return { kind, limit: Number.isFinite(limit) ? limit : null }
    }
  }
  return null
}
