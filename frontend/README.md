# Frontend Service

Vue 3 + TypeScript + Vite application with layered architecture and composition API.

## Table of Contents

- [Features](#features)
- [Project Structure](#project-structure)
- [Architecture](#architecture)
- [Running Locally](#running-locally)
- [Building for Production](#building-for-production)

---

## Features

- **Vue 3** with Composition API and `<script setup>`
- **TypeScript** for type safety
- **Layered Architecture** (Services, Composables, Utils)
- **Responsive Design** with modern CSS
- **Error Handling** with custom error classes
- **Loading States** with spinners and feedback
- **API Integration** with timeout and retry logic

---

## Project Structure

```
frontend/
├── src/
│   ├── components/          # Vue components
│   │   ├── ItemCard.vue    # Item display card
│   │   └── ItemsList.vue   # Items list container
│   │
│   ├── composables/         # Composition API logic
│   │   └── useItems.ts     # Items state management
│   │
│   ├── services/            # API services
│   │   └── api.service.ts  # HTTP client & items API
│   │
│   ├── types/               # TypeScript definitions
│   │   └── item.ts         # Item interfaces
│   │
│   ├── config/              # Configuration
│   │   └── app.config.ts   # App settings
│   │
│   ├── utils/               # Utility functions
│   │   ├── errors.ts       # Error handling
│   │   └── helpers.ts      # Helper functions
│   │
│   ├── assets/              # Static assets
│   ├── App.vue              # Root component
│   ├── main.ts              # Entry point
│   └── style.css            # Global styles
│
├── public/                  # Public static files
├── .env.exemple             # Environment variables template
├── index.html               # HTML template
├── package.json             # Dependencies
├── tsconfig.json            # TypeScript config
├── vite.config.ts           # Vite config
└── README.md                # This file
```

---

## Architecture

### Layered Structure

```
┌─────────────────────────────────────────┐
│           COMPONENTS LAYER              │
│  (ItemsList.vue, ItemCard.vue)          │
│  - Presentation logic                   │
│  - User interactions                    │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│          COMPOSABLES LAYER              │
│  (useItems.ts)                          │
│  - State management                     │
│  - Business logic                       │
│  - Reusable logic                       │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│           SERVICES LAYER                │
│  (api.service.ts)                       │
│  - HTTP requests                        │
│  - API communication                    │
│  - Error handling                       │
└──────────────┬──────────────────────────┘
               │
               ▼
┌─────────────────────────────────────────┐
│            UTILS LAYER                  │
│  (errors.ts, helpers.ts)                │
│  - Helper functions                     │
│  - Data transformation                  │
│  - Error utilities                      │
└─────────────────────────────────────────┘
```

### Design Patterns

| Pattern                    | Usage                                | Location                  |
|----------------------------|--------------------------------------|---------------------------|
| **Composition API**        | Component logic organization         | `composables/`            |
| **Service Pattern**        | API abstraction                      | `services/`               |
| **Custom Errors**          | Structured error handling            | `utils/errors.ts`         |
| **TypeScript Interfaces**  | Type safety and contracts            | `types/`                  |
| **Singleton Services**     | Single API service instance          | `api.service.ts`          |
| **Props & Emits**          | Component communication              | All `.vue` files          |

### Key Concepts

**Composables** (`composables/`):
- Reusable stateful logic
- Reactive state management
- Side effects handling
- Business logic encapsulation

**Services** (`services/`):
- API communication layer
- Request/response handling
- Timeout management
- Error transformation

**Utils** (`utils/`):
- Pure functions
- Data transformations
- Helper utilities
- No side effects

---

## Running Locally

### With Docker (recommended)

```bash
# From project root
docker compose up -d frontend

# View logs
docker compose logs frontend -f
```

### Without Docker

```bash
# Install dependencies
npm install

# Start development server
npm run dev

# Open browser at http://localhost:5173
```

**Prerequisites:**
- Node.js 18+ installed
- API running at `http://localhost:3000`

---

## Building for Production

### Build static files

```bash
# Build for production
npm run build

# Preview production build
npm run preview
```

**Output:** Optimized static files in `dist/`

### Type Checking

```bash
# Run TypeScript compiler
npm run build
```

TypeScript checks are included in the build process.

---

## Environment Variables

See [`.env.exemple`](.env.exemple) for available variables.

**Required variables:**
```env
VITE_API_URL=http://localhost:3000
```

**Note:** 
- In Docker, variables are configured in root `/.env`
- For local dev, create `frontend/.env` from `.env.exemple`
- Only variables prefixed with `VITE_` are exposed to the client

---

## Development Guidelines

### Component Structure

```vue
<script setup lang="ts">
// 1. Imports
import { ref } from 'vue'
import type { MyType } from '../types'

// 2. Props & Emits
interface Props {
  myProp: string
}
defineProps<Props>()

// 3. Composables
const { data, loading } = useMyComposable()

// 4. Local state
const localState = ref('')

// 5. Methods
function handleClick() {
  // ...
}
</script>

<template>
  <!-- Template -->
</template>

<style scoped>
/* Styles */
</style>
```

### Naming Conventions

- **Components**: PascalCase (`ItemCard.vue`)
- **Composables**: camelCase with `use` prefix (`useItems.ts`)
- **Services**: camelCase with `Service` suffix (`api.service.ts`)
- **Types**: PascalCase (`Item`, `ApiResponse`)
- **Files**: kebab-case or camelCase

### Type Safety

Always use TypeScript interfaces:
```typescript
// ✅ Good
interface Item {
  id: number
  title: string
}

// ❌ Avoid
const item: any = { ... }
```

---

## Troubleshooting

### Dev server won't start

```bash
# Clear node_modules and reinstall
rm -rf node_modules package-lock.json
npm install
```

### Can't connect to API

1. Check API is running: `curl http://localhost:3000/status`
2. Verify `VITE_API_URL` in `.env`
3. Check CORS configuration on API

### Build errors

```bash
# Type check only
npx vue-tsc --noEmit

# Check specific file
npx vue-tsc --noEmit src/path/to/file.vue
```

---

**Vue Version:** 3.5+  
**Vite Version:** 7.1+  
**TypeScript Version:** 5.9+  
**Documentation:** https://vuejs.org/guide/
