# Travel Expenses: Architecture Principles

## Guiding Philosophy

**Pragmatic > Over-Engineered**

We use Clean Architecture concepts where they reduce complexity, not where they add it. The app is built for **maintenance and clarity**, not for abstract architectural purity.

---

## Application Architecture

### Layered Structure

```
app/                     Entry points (main.dart, app.dart, routing)
├── app.dart             Root MaterialApp, theme, localization
├── app_router.dart      Navigation routing (minimal, single home route)
└── home_entry_screen.dart Entry point (onboarding or trips list)

core/                    Shared services (NOT for state)
├── constants/           App-wide constants
├── database/            SQLite initialization and schema
├── extensions/          Reusable Dart/Flutter extensions (RTL, locale helpers)
├── finance/             Finance utilities (currency, conversion, formatting)
├── providers/           Global Riverpod providers (Database, Settings)
├── theme/               Material design system
└── design_system/       Shared design tokens

features/                Domain-specific features
├── [feature_name]/
│   ├── data/            Repository pattern (database access)
│   ├── domain/          Models and business logic
│   └── presentation/    UI screens and widgets

shared/                  UI-only utilities
└── widgets/             Reusable UI components (not state, not business logic)
```

### Why This Structure

- **Per-feature organization** reduces cross-feature dependencies
- **Separate `core/` from `features/`** keeps global concerns isolated
- **Data layer per feature** (not centralized) simplifies feature extraction
- **Shared widgets only** (no shared state managers or business logic) prevents tangled coupling

---

## State Management: Riverpod

### Pattern

```dart
// 1. Define state holder (AsyncNotifier or plain Notifier)
class ExpenseController extends AsyncNotifier<List<Expense>> {
  Future<List<Expense>> build() async { ... }
  Future<void> addExpense(Expense expense) async { ... }
}

// 2. Expose via provider
final expenseControllerProvider = AsyncNotifierProvider<ExpenseController, List<Expense>>(
  () => ExpenseController(),
);

// 3. Use in UI
final state = ref.watch(expenseControllerProvider);
state.when(
  data: (expenses) => ...,
  loading: () => ...,
  error: (err, stack) => ...,
);
```

### Naming Conventions

- **Controller extends AsyncNotifier** – async operations (database read/write)
- **Notifier extends StateNotifier** – sync operations (settings, local state)
- **Provider naming** – `[feature][name]Provider` or `[name]ControllerProvider`

### Why Riverpod

- **Compile-time safe** (no runtime key issues like Provider package)
- **Family & conditional** modifiers for parameterized state
- **Immutable providers** (no mutable global state creeping in)
- **Minimal boilerplate** compared to other state managers

---

## Data Persistence: SQLite

### Database Schema

- **Single database file** (offline-first, no multi-database complexity)
- **Version-based migrations** (migration_v1, migration_v2, etc.)
- **Current schema: v15** (managed in `lib/core/database/migrations/`)
- **Initialization on first run** (automatic, no manual setup)

### Data Flow

```
SQLite File ← → Database Service (lib/core/database/database_service.dart)
                 ↓
            Repository Pattern (features/*/data/repositories/)
                 ↓
            Riverpod AsyncNotifier Controllers
                 ↓
            UI Layer (features/*/presentation/)
```

### Repository Pattern

Each feature data layer includes a repository:

```dart
// features/expenses/data/repositories/expense_repository.dart
class ExpenseRepository {
  Future<List<Expense>> fetchExpenses(int tripId) async { ... }
  Future<void> insertExpense(Expense expense) async { ... }
  Future<void> updateExpense(Expense expense) async { ... }
  Future<void> deleteExpense(int id) async { ... }
}
```

- Repositories **encapsulate database logic**
- Controllers **orchestrate** repositories and state
- UI **never directly touches the database**

---

## Internationalization

### Supported Locales
- **English (en)**
- **Arabic (ar)** – RTL support via Flutter Material

### Implementation

- **ARB files** for translations (`lib/l10n/app_*.arb`)
- **Flutter gen-l10n** auto-generates `AppLocalizations`
- **RTL detection** via Directionality context or locale code
- **RTL extension** (`lib/core/extensions/rtl_extension.dart`) centralizes RTL checks

### Locale Constants
- **`SupportedLocales.arabic`** and **`SupportedLocales.english`** replace hardcoded strings
- Eliminates `== 'ar'` and `== 'en'` scattered throughout codebase

---

## Design System

### Theme
- **Material 3 color scheme** (no custom design system reinvention)
- **Cohesive spacing and typography** via `AppTheme`
- **Dark and light modes** (automatic via system setting)
- **Custom fonts** (Cairo for Arabic, inter for English)

### Widget Organization
- **Shared widgets** live in `lib/shared/widgets/`
- **Feature-specific widgets** live in `features/*/presentation/widgets/`
- **Avoid deep widget trees** – extract components for clarity

---

## Code Organization Rules

### Cross-Feature Imports: Discouraged

```dart
// ❌ Avoid: Feature presentation → Feature presentation
import 'package:travel_expenses/features/expenses/presentation/...';

// ✅ Prefer: Feature presentation → Shared widgets
import 'package:travel_expenses/shared/widgets/...';

// ✅ OK: Feature logic → Feature logic
import '../data/repositories/...';
```

### Circular Dependencies: None Allowed

- Use shared providers in `core/providers/` if needed
- Keep features independent; avoid bi-directional imports

### Constants and Enums

- **App-wide constants** → `lib/core/constants/`
- **Feature-specific constants** → `features/[feature]/data/constants.dart`

---

## Testing Strategy

### Unit Tests
- **Repository tests** – mock database, verify data layer
- **Provider tests** – mock repositories, test state transitions
- **Utility tests** – formatters, validators, business logic

### Widget Tests
- **Screen-level components** – test user interactions
- **Shared widgets** – test reusability across features

### No E2E or Integration Tests (Currently)
- Manual testing preferred for UI/UX validation
- Focus on unit test coverage for data layer

---

## What We Avoid

### Over-Architecture
- ❌ No abstract base classes for simple repositories
- ❌ No service locator pattern (Riverpod providers are the locator)
- ❌ No multiple abstraction layers between UI and data
- ❌ No code generation for boilerplate (keep it readable)

### Feature Bloat
- ❌ No database connection pooling (single connection per app)
- ❌ No caching layer (SQLite IS the cache)
- ❌ No analytics SDK integration
- ❌ No third-party API clients (offline-first, not cloud-dependent)

### Common Anti-Patterns
- ❌ Business logic in UI widgets
- ❌ Direct database queries in controllers
- ❌ Global mutable state outside Riverpod
- ❌ Hardcoded strings (use l10n + constants)

---

## Pragmatic Excellence

The goal is **maintainable, clear code that works reliably offline**, not architecturally perfect or maximally abstract code. When in doubt:

1. **Can a new developer understand this in 5 minutes?**
2. **Would this code survive a year of maintenance?**
3. **Does this pattern scale if we add 10 more features?**

If yes to all three → it's the right level of architecture.
