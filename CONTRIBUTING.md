# Contributing to ReClaim™

Thank you for your interest in contributing to ReClaim. We maintain high engineering standards to ensure the stability of behavioral enforcement.

## Code of Conduct

By participating in this project, you agree to abide by our professional standards.

## Development Workflow

### 1. Branching Model
- All development happens in feature branches: `feature/your-feature-name`.
- Use `refactor/` for structural changes and `fix/` for bug fixes.
- Merge requests must target the `main` branch.

### 2. Commit Message Standards (Conventional Commits)
We enforce [Conventional Commits](https://www.conventionalcommits.org/). This allows us to automate changelog generation.

Format: `<type>(<scope>): <description>`

Types:
- `feat`: A new feature
- `fix`: A bug fix
- `docs`: Documentation changes
- `style`: Formatting, missing semi colons, etc; no code change
- `refactor`: Refactoring production code
- `test`: Adding missing tests, refactoring tests; no production code change
- `chore`: Updating build tasks, package manager configs, etc; no production code change

### 3. Architecture Guidelines

#### Flutter (Mobile)
- **Domain-Driven**: Business logic must reside in `services/`.
- **Stateless Components**: Use `widgets/` for reusable, pure UI elements.
- **Constants**: No hardcoded strings or values; use `constants/`.

#### Node.js (Backend)
- **Layered Architecture**:
  - `presentation/`: Routes, controllers, schemas.
  - `services/`: Business logic and orchestrations.
  - `db/repositories/`: Data access logic.
  - `jobs/`: Background workers and cron tasks.
  - `domain/`: Shared types and core logic engines.

### 4. Code Quality
- **TypeScript**: No `any` types. Use Zod for runtime validation.
- **Dart**: Run `flutter analyze` before committing. Zero warnings allowed.
- **ES Modules**: Backend uses ESM. Always include `.js` extensions in imports.

## Pull Request Process

1. Fork the repository and create your branch from `main`.
2. Ensure all tests pass (`npm test` in backend, `flutter test` in mobile).
3. Update the documentation if you've added new features or changed APIs.
4. Submit the PR with a clear description of the changes and the "Why" behind them.

---
*Build with intent. Code for autonomy.*
