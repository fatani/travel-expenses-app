# Engineering Decisions Log

Travel Expenses Pro

---

## Decision 001 — No Money Model Migration Yet

Status: ACTIVE

We intentionally decided NOT to migrate:

* double → integer cents
* double → decimal library

Reason:
The current priority is financial semantic stabilization,
not schema-level refactoring.

Current strategy:

* stabilize FX semantics
* stabilize reporting truth
* prevent misleading calculations
* keep migrations frozen

Future reconsideration:
Only after:

* FX invariants stabilize
* reporting rules stabilize
* snapshot semantics become stable

---

## Decision 002 — FX Snapshots Are Immutable

Status: ACTIVE

Expense FX snapshots represent:

* the truth at transaction time
  not
* current market rates.

Therefore:

* changing exchange rates later must NOT rewrite history
* changing home currency later must NOT rewrite past expenses

---

## Decision 003 — Cross-Currency Totals Are Dangerous

Status: ACTIVE

The app must NOT:

* sum raw amounts across currencies
* compare raw category totals across currencies
* generate percentage insights from mixed currencies

Unless:

* normalization exists
* the normalization source is explicit
* disclosure is shown to the user

---

## Decision 004 — No Enterprise Refactor

Status: ACTIVE

The project intentionally avoids:

* Clean Architecture overengineering
* excessive abstractions
* generic repository systems
* unnecessary layers

Reason:
The project is:

* MVP-first
* local-first
* UX-driven
* speed-oriented

---

## Decision 005 — Travel-First, Not Accounting-First

Status: ACTIVE

The product is:
Travel Financial Operating System

Not:

* ERP
* accounting suite
* banking core system

Financial correctness matters,
but UX simplicity and speed remain critical priorities.

---

## Decision 006 — Controlled Evolution Only

Status: ACTIVE

Changes must be:

* isolated
* reversible
* low-risk
* incremental

Avoid:

* large rewrites
* system-wide refactors
* multi-domain migrations

---

## Decision 007 — Truth Before Intelligence

Status: ACTIVE

The product must stabilize:

* financial truth
* reporting correctness
* FX semantics

before:

* AI insights
* advanced predictions
* automation layers

False intelligence is worse than no intelligence.
