---
name: node-ts-standards
description: Node.js, TypeScript, and JavaScript conventions — strict TypeScript, ESM, JSDoc on exports, named exports, node: prefixed core modules, and colocated behaviour tests. Use when writing, reviewing, or refactoring Node, TypeScript, or JavaScript code, or .ts, .tsx, .js, and .mjs files.
---

# Node.js, TypeScript, and JavaScript standards

## Types

- TypeScript with `strict: true` for all new projects
- No `any` — use `unknown` and narrow, or define a proper type
- Explicit return types on exported functions

## Modules

- ESM (`import`/`export`) over CommonJS
- Named exports over default exports
- The `node:` prefix for core modules: `import { readFile } from 'node:fs/promises'`

## Language

- `const` by default; `let` only where reassignment is genuinely needed
- `async`/`await` over raw promise chains, with errors handled explicitly
- Prefer the standard library before adding a dependency

## Documentation

JSDoc on exported functions — a brief description, `@param`, and `@returns`:

```ts
/**
 * Resolve a feed URL to its canonical form.
 *
 * @param input - The raw URL as supplied by the user.
 * @returns The canonical URL, or null when the input is not a feed.
 */
export function canonicalise(input: string): string | null {
```

## Testing

- Colocate tests with the code they cover
- Descriptive test names that state the behaviour under test
- Test behaviour, not implementation

## Tooling

Follow whatever the project already uses — check for a lock file (`package-lock.json`,
`pnpm-lock.yaml`, `yarn.lock`, `bun.lockb`) before choosing a package manager.

## Verification before commit

```bash
tsc --noEmit
npm test
```
