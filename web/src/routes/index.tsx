import { createFileRoute } from '@tanstack/react-router'

export const Route = createFileRoute('/')({
  component: HomePage,
})

function HomePage() {
  return (
    <section className="max-w-xl space-y-2">
      <h1 className="text-2xl font-semibold">Gradus</h1>
      <p className="text-neutral-600">
        Gestionale coach. Scaffold pronto: qui arriveranno atleti e mesocicli.
      </p>
    </section>
  )
}
