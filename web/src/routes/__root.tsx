import { createRootRoute, Outlet } from '@tanstack/react-router'

export const Route = createRootRoute({
  component: RootLayout,
})

function RootLayout() {
  return (
    <div className="min-h-screen bg-neutral-50 text-neutral-900">
      <header className="border-b border-neutral-200 bg-white px-6 py-4">
        <span className="text-lg font-semibold">Gradus</span>
      </header>
      <main className="px-6 py-8">
        <Outlet />
      </main>
    </div>
  )
}
