import { PlayCircleIcon, XIcon } from '@phosphor-icons/react'
import { useMutation, useQueryClient } from '@tanstack/react-query'
import { useState, type FormEvent } from 'react'
import { Button } from '@/components/ui/button'
import { Collapsible } from '@/components/ui/collapsible'
import { Input } from '@/components/ui/input'
import { fieldErrors } from '@/lib/auth'
import { addExerciseVideo, type ExerciseVideo, removeExerciseVideo } from '@/lib/library'
import { messages } from '@/lib/messages'
import { videoPlatform, videoSchema } from '@/lib/videos'

const m = messages.app.exercises.videos

/** I link video che il coach ha messo a un esercizio (anche del catalogo), con il modulo per aggiungerne. */
export function ExerciseVideos({
  coachId,
  exerciseId,
  videos,
}: {
  coachId: string
  exerciseId: string
  videos: ExerciseVideo[]
}) {
  const queryClient = useQueryClient()
  const [errors, setErrors] = useState<Record<string, string | undefined>>({})
  const [formKey, setFormKey] = useState(0)
  const refresh = () => queryClient.invalidateQueries({ queryKey: ['exercises'] })

  const add = useMutation({
    mutationFn: (video: { url: string; title: string | null }) =>
      addExerciseVideo(coachId, exerciseId, video),
    onSuccess: async () => {
      setFormKey((k) => k + 1)
      await refresh()
    },
  })
  const remove = useMutation({
    mutationFn: (id: string) => removeExerciseVideo(coachId, id),
    onSuccess: refresh,
  })

  function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    add.reset()
    const form = new FormData(event.currentTarget)
    const parsed = videoSchema.safeParse({ url: form.get('url'), title: form.get('title') })
    if (!parsed.success) return setErrors(fieldErrors(parsed.error))
    if (videos.some((v) => v.url === parsed.data.url)) return setErrors({ url: m.errors.duplicate })
    setErrors({})
    add.mutate(parsed.data)
  }

  return (
    <Collapsible title={m.title(videos.length)}>
      <p className="text-xs text-muted-foreground">{m.hint}</p>
      {videos.length === 0 ? (
        <p className="text-sm text-muted-foreground">{m.empty}</p>
      ) : (
        <ul className="divide-y rounded-md border">
          {videos.map((v) => {
            const platform = m.platforms[videoPlatform(v.url)]
            return (
              <li key={v.id} className="flex items-center gap-2 py-1 pr-1 pl-3">
                <PlayCircleIcon className="shrink-0 text-muted-foreground" />
                <a
                  href={v.url}
                  target="_blank"
                  rel="noopener noreferrer"
                  aria-label={`${m.open(platform)}${v.title ? `: ${v.title}` : ''}`}
                  className="min-w-0 flex-1 truncate text-sm hover:underline focus-visible:underline focus-visible:outline-none"
                >
                  <span className="font-medium">{platform}</span>
                  <span className="text-muted-foreground"> · {v.title ?? v.url}</span>
                </a>
                <Button
                  variant="ghost"
                  size="icon"
                  aria-label={`${m.remove}: ${v.title ?? v.url}`}
                  title={m.remove}
                  disabled={remove.isPending}
                  onClick={() => remove.mutate(v.id)}
                >
                  <XIcon />
                </Button>
              </li>
            )
          })}
        </ul>
      )}
      <form key={formKey} noValidate onSubmit={submit} className="flex flex-wrap items-start gap-3">
        <label className="grid min-w-56 flex-[2] gap-1.5 text-xs text-muted-foreground">
          {m.url}
          <Input
            name="url"
            type="url"
            inputMode="url"
            placeholder={m.urlPlaceholder}
            aria-invalid={errors.url ? true : undefined}
            className="h-9 text-sm text-foreground"
          />
          {errors.url && (
            <span role="alert" className="text-destructive">
              {errors.url}
            </span>
          )}
        </label>
        <label className="grid min-w-40 flex-1 gap-1.5 text-xs text-muted-foreground">
          {m.titleLabel}
          <Input name="title" className="h-9 text-sm text-foreground" />
          {errors.title && (
            <span role="alert" className="text-destructive">
              {errors.title}
            </span>
          )}
        </label>
        <Button type="submit" variant="outline" disabled={add.isPending} className="mt-5">
          {add.isPending ? m.adding : m.add}
        </Button>
        {add.isError && (
          <p role="alert" className="basis-full text-sm text-destructive">
            {m.errors.generic}
          </p>
        )}
      </form>
    </Collapsible>
  )
}
