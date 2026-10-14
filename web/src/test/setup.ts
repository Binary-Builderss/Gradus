import '@testing-library/jest-dom/vitest'
import { cleanup } from '@testing-library/react'
import { afterEach } from 'vitest'

// Senza `globals` Vitest non ripulisce il DOM da solo tra un test e l'altro.
afterEach(cleanup)
