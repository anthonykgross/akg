# extends-local-team

## Project context

- Minimal React app (Vite); single component in src/App.jsx

## Commands

- Test: `npm test`
- Lint: `npm run lint`
- Build: `npm run build`

## Workflow

1. Write a failing test first, then the code, then refactor.
2. Review: run the tests.
3. Done when:
   - [ ] tests pass
   - [ ] lint clean
   - [ ] docs updated

## Team conventions

- Components in PascalCase, one component per file.
- State management: local state first, a store only when shared by 3+ components.
- Every component has a test next to it (`Foo.test.jsx`).

## Rules

- Ask before committing, pushing or deleting files.
