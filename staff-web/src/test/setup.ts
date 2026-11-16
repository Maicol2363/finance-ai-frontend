import '@testing-library/jest-dom/vitest'
import { cleanup, configure } from '@testing-library/react'
import { afterEach } from 'vitest'

// Full-suite runs with coverage are CPU bound; the default 1 s findBy* timeout is too tight.
configure({ asyncUtilTimeout: 5000 })

afterEach(cleanup)
