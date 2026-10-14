import { describe, expect, it } from 'vitest'
import { diffMuscles, exerciseSchema } from './exerciseForm'

const ok = { name: ' Curl ai cavi ', video_url: '', notes: '  ', muscles: [{ muscle: 'biceps', weight: 1 }] }

describe('exerciseSchema', () => {
  it('normalizza nome, video e note vuoti', () =>
    expect(exerciseSchema.parse(ok)).toEqual({
      name: 'Curl ai cavi',
      video_url: null,
      notes: null,
      muscles: [{ muscle: 'biceps', weight: 1 }],
    }))
  it('accetta solo video http(s)', () => {
    expect(exerciseSchema.safeParse({ ...ok, video_url: 'https://youtu.be/abc' }).success).toBe(true)
    expect(exerciseSchema.safeParse({ ...ok, video_url: 'javascript:alert(1)' }).success).toBe(false)
    expect(exerciseSchema.safeParse({ ...ok, video_url: 'youtube.com/x' }).success).toBe(false)
  })
  it('nome obbligatorio', () => expect(exerciseSchema.safeParse({ ...ok, name: ' ' }).success).toBe(false))
  it('almeno un muscolo, senza doppioni, peso in (0, 1]', () => {
    expect(exerciseSchema.safeParse({ ...ok, muscles: [] }).success).toBe(false)
    const dup = [
      { muscle: 'biceps', weight: 1 },
      { muscle: 'biceps', weight: 0.5 },
    ]
    expect(exerciseSchema.safeParse({ ...ok, muscles: dup }).success).toBe(false)
    for (const weight of [0, -1, 1.2])
      expect(exerciseSchema.safeParse({ ...ok, muscles: [{ muscle: 'biceps', weight }] }).success).toBe(false)
    expect(exerciseSchema.safeParse({ ...ok, muscles: [{ muscle: 'biceps', weight: 0.05 }] }).success).toBe(
      true,
    )
  })
})

describe('diffMuscles', () => {
  it('scrive solo i pesi cambiati o nuovi e toglie quelli spariti', () => {
    const saved = [
      { muscle: 'chest', weight: 1 },
      { muscle: 'triceps', weight: 0.5 },
      { muscle: 'front_delts', weight: 0.5 },
    ] as const
    const next = [
      { muscle: 'chest', weight: 1 },
      { muscle: 'triceps', weight: 0.75 },
      { muscle: 'abs', weight: 0.25 },
    ] as const
    expect(diffMuscles(saved, next)).toEqual({
      upsert: [
        { muscle: 'triceps', weight: 0.75 },
        { muscle: 'abs', weight: 0.25 },
      ],
      remove: ['front_delts'],
    })
  })
})
