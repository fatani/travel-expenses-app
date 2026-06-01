# Stage 1.9.10 — Local Backup & Restore Readiness Audit

**Date:** 2026-06-01  
**App:** CalmLedger / Travel Expenses Pro  
**Schema Version:** 17  
**Auditor:** Senior Flutter Data Safety Architect

---

## 1. Current Data Storage Assessment

### Database File

| Property | Value |
|---|---|
| File name | `travel_expenses.db` |
| Location (Android) | `/data/data/com.<package>/databases/travel_expenses.db` |
| Location (iOS) | `<NSLibraryDirectory>/databases/travel_expenses.db` |
| sqflite path resolver | `getDatabasesPath()` |
| Schema version | **17** |
| Foreign keys | Enabled (`PRAGMA foreign_keys = ON`) |

The database is in **Android internal private storage**. It is NOT accessible without either root, ADB backup (deprecated on Android 12+), or the app itself explicitly exposing the file.

### Tables and What They Hold

| Table | What It Stores | Risk if Lost |
|---|---|---|
| `trips` | Trip metadata, currencies, budget, dates | Critical — parent of everything |
| `expenses` | Every expense entry with full financial data | Critical — the core data |
| `cash_transactions` | Cash inflows, withdrawals, expense deductions | High — wallet history |
| `trip_cash_balances` | Derived current balances per currency per trip | Medium — recomputable from cash_transactions |
| `manual_exchange_rates` | User-entered FX rates, scoped per trip | Medium — rates affect reports accuracy |
| `cards` | Card profiles with bank, network, tier, last4 | Medium — linked to expenses via card_profile_id |
| `settings` | App settings (home currency, locale) | Low — re-enterable |
| `user_financial_profile` | Home country, home currency, onboarding state | Low — re-enterable |

**Total data units at risk:** trips + all their expenses + cash wallet history + manual FX rates + card profiles.

### Migration System Health

The migration system uses a **hybrid approach**:

- `onUpgrade(oldVersion, newVersion)` — versioned migration blocks (versions 2–17)
- `onOpen` — `_ensure*` guards that defensively add columns if missing

This is safe for forward migrations. However, it has one important backup/restore implication: **there is no downgrade path**. If a backup from schema v17 is restored onto an app running schema v15, `onUpgrade` will run normally. But a backup from v17 cannot be used on an older app version — columns will be missing and the app will crash on read.

**Key risk:** The `_purgeOrphanFinancialRows()` on v17 upgrade deletes expenses with no matching trip. This is correct for integrity but means: **a partial restore (trips missing, expenses present) will cause silent data deletion on next open.**

---

## 2. Existing Export/Import Capabilities

### What Exists

| Capability | Format | Location | Purpose |
|---|---|---|---|
| Trip CSV export | `.csv` | `getApplicationDocumentsDirectory()/exports/` | Reporting only |
| Trip PDF export | `.pdf` | `getApplicationDocumentsDirectory()/exports/` | Reporting only |
| File sharing | via `share_plus` | System share sheet | Delivery to Files/Drive/email |

### What Does NOT Exist

- No raw data backup/export
- No JSON export
- No SQLite file copy
- No backup manifest or schema version metadata
- No import or restore flow of any kind
- No `archive` / `zip` package in `pubspec.yaml`

### Critical Gap

The CSV/PDF exports are **reporting artifacts only**. They are NOT restorable. Exporting all trips as CSV and then losing the phone means: all data is gone. The user has a readable file but no way to get their data back into the app.

---

## 3. Recommended Release-Ready Backup Strategy

### Decision: Option B — JSON Backup (with Option C deferred to Phase 2)

After evaluating all options:

**Option A (raw SQLite file copy):**
- Android scoped storage makes this hard to expose to the user safely without a file picker
- `getDatabasesPath()` returns a path in private internal storage
- The DB file must be closed before copying or it risks corruption from WAL state
- Schema version lock-in: the restored file must match the app's current schema expectations
- Restore = replace the file = total overwrite with no validation
- **Verdict: Too risky for MVP. Feasible technically but fragile.**

**Option B (JSON backup) — RECOMMENDED for v1:**
- All 8 tables are serializable to JSON using existing `toMap()` methods already present on every model
- Human-readable — user can inspect/verify their backup
- Versioned with `schema_version` + `app_version` + `exported_at` fields
- Survives app reinstall, phone transfer, schema evolution
- Can be validated before restore — check table counts, version compatibility
- Delivered via `share_plus` (same mechanism as CSV/PDF — already works)
- Imported via a file picker (needs `file_picker` package, ~30min to add)
- No schema coupling risk — the app reads the JSON and re-inserts via existing repositories
- **Verdict: Correct choice for release.**

**Option C (ZIP: DB + metadata):**
- Adds `archive` package dependency
- SQLite WAL state must be flushed before copy — requires `PRAGMA wal_checkpoint(TRUNCATE)`
- More complex restore path
- No meaningful advantage over JSON for this data size (travel expenses are not gigabytes)
- Better for Phase 2 when media attachments (receipts) exist
- **Verdict: Defer to Phase 2.**

**Option D (Cloud sync):**
- Out of scope per product constraints.
- **Verdict: Future scope only.**

---

## 4. Restore Risk Analysis

### Risks With No Backup (current state)

| Scenario | Data Loss |
|---|---|
| Phone lost | 100% — no recovery path |
| Phone factory reset | 100% |
| App uninstalled | 100% on Android (uninstall purges private storage) |
| Phone upgrade (data transfer) | Partial — depends on Android backup settings which users rarely configure |
| App update gone wrong | 100% if private storage is cleared |

### Risks of JSON Restore

| Risk | Severity | Mitigation |
|---|---|---|
| Restore replaces existing data silently | Critical | Always show confirmation dialog: "This will replace all current data. This cannot be undone." |
| Backup from newer schema has unknown fields | Low | JSON unknown fields are safely ignored on import |
| Backup from older schema missing fields | Low | Use null-safe column defaults during import |
| trip_cash_balances out of sync with cash_transactions | Medium | Recompute balances from transactions during restore instead of importing the snapshot |
| card_profile_id references after cards table restore | Medium | Restore cards BEFORE expenses; verify FK references after restore |
| Partial restore (file corruption mid-write) | Medium | Write to temp file first, then atomically move; validate record counts before committing |
| User restores wrong file | Low | Show backup metadata (date, trip count, expense count) before confirming |

### Restore Order (non-negotiable)

```
1. user_financial_profile   (no dependencies)
2. settings                 (no dependencies)
3. cards                    (no dependencies)
4. trips                    (no dependencies)
5. manual_exchange_rates    (depends on trips)
6. expenses                 (depends on trips + cards)
7. cash_transactions        (depends on trips + expenses)
8. trip_cash_balances       (depends on trips — or recompute from cash_transactions)
```

Violating this order will cause FK violations and silent data loss via `_purgeOrphanFinancialRows`.

---

## 5. Required Schema/Version Metadata

Every backup file must include a metadata envelope:

```json
{
  "backup_format_version": 1,
  "schema_version": 17,
  "app_version": "1.0.0",
  "exported_at": "2026-06-01T12:00:00.000Z",
  "trip_count": 3,
  "expense_count": 142,
  "tables": {
    "user_financial_profile": [...],
    "settings": [...],
    "cards": [...],
    "trips": [...],
    "manual_exchange_rates": [...],
    "expenses": [...],
    "cash_transactions": [...],
    "trip_cash_balances": [...]
  }
}
```

`backup_format_version` is the backup format, separate from `schema_version`. If you later change the JSON structure, bump `backup_format_version` — not `schema_version`.

The restore flow uses `schema_version` to determine if a migration bridge is needed. For v1 release: if `schema_version` in backup > app's current schema, **refuse restore** with a clear message (user needs to update the app first).

---

## 6. UX Flow Recommendation

### Backup Flow

```
Settings → "Backup & Restore"
  → [Create Backup]
      → App collects all tables → builds JSON → writes to temp file
      → share_plus opens system sheet (Files, Drive, Email, etc.)
      → User saves to location of their choice
  → Shows: "Backup created: 3 trips, 142 expenses"
```

**No new share mechanism needed.** `share_plus` is already used for CSV/PDF — same pattern.

### Restore Flow

```
Settings → "Backup & Restore"
  → [Restore from Backup]
      → File picker opens (user selects .clbackup or .json file)
      → App reads and validates file:
          - Is this a valid CalmLedger backup?
          - Schema version compatible?
          - Shows preview: "3 trips, 142 expenses, backed up on June 1 2026"
      → Confirmation dialog (non-dismissible):
          ⚠️ "Restoring will permanently replace all your current data.
              This cannot be undone. Are you sure?"
          [Cancel]  [Replace All Data]
      → Restore runs inside a DB transaction
      → On success: app reloads all Riverpod providers → navigates to home
      → On failure: transaction rolled back → user sees error + original data intact
```

**One rule:** Never commit a restore partially. It is all-or-nothing inside a single transaction.

---

## 7. Testing Plan

### Unit Tests Required

| Test | What to Verify |
|---|---|
| `BackupSerializer` round-trip | All 8 tables serialize → deserialize → data matches |
| Schema version in envelope | Correct version written |
| `trip_cash_balances` recompute | Balances match what cash_transactions sum to |
| FK restore order | Restore with trips before expenses succeeds; reverse order fails with FK error |
| Corrupt file handling | Truncated JSON throws `FormatException`, not a crash |
| Newer schema version refusal | Backup with `schema_version: 99` is rejected gracefully |
| Empty database backup | Produces valid JSON with empty arrays |
| Restore is transactional | Mid-restore failure leaves original data intact |

### Integration Tests Required

| Test | What to Verify |
|---|---|
| Full round-trip on real sqflite_ffi DB | Export full DB → wipe DB → restore → all rows match |
| card_profile_id integrity after restore | Expenses reference correct card IDs post-restore |
| cash_transactions + balances coherence | Balance after restore matches sum of non-reversed transactions |
| Riverpod state refresh after restore | All providers reload correctly, no stale cache shown |

---

## 8. Implementation Scope Estimate

### New files needed (minimal)

```
lib/features/backup/
  data/
    backup_serializer.dart       ~80 lines  — toJson / fromJson for all tables
    backup_file_service.dart     ~60 lines  — write/read file, share_plus, file_picker
  domain/
    backup_manifest.dart         ~30 lines  — metadata model
  presentation/
    backup_restore_screen.dart   ~120 lines — UI for create/restore with confirmation
```

**Total new code: ~290 lines. No existing files need modification.**

### New dependency

```yaml
file_picker: ^8.x.x   # for restore file selection
```

`share_plus`, `path_provider`, and `path` are already present.

### Estimate

| Task | Time |
|---|---|
| BackupSerializer (all 8 tables → JSON) | 3–4h |
| BackupFileService (write, read, share, pick) | 2h |
| BackupRestoreScreen (UI + confirmation) | 3h |
| Unit tests (round-trip, edge cases) | 3h |
| Integration test (full DB round-trip) | 2h |
| **Total** | **~13–14h** |

This is a standalone feature with no risk to existing code.

---

## 9. What MUST Be Done Before Release

These are blockers for shipping a local-first app to real users:

1. **Implement JSON backup export** — without this, every user is one phone loss away from losing everything.
2. **Implement JSON restore import** — export-only is insufficient; the restore path is what makes backup real.
3. **Confirmation dialog before restore** — mandatory. Silent data replacement is unacceptable.
4. **trip_cash_balances recompute on restore** — do NOT trust the snapshot; recompute from `cash_transactions` to prevent balance drift. This avoids a class of corruption bugs entirely.
5. **File extension: `.clbackup`** — register a custom extension so the OS associates the file with the app (Android intent filter, iOS UTType). Without this, users cannot easily tap-to-restore from Files. This is a small manifest change but critical for UX.

---

## 10. What Can Wait for Phase 2

These are improvements, not blockers:

| Feature | Why It Can Wait |
|---|---|
| ZIP + raw SQLite (Option C) | JSON covers all data. ZIP adds value only when receipts/images exist. |
| Automatic scheduled backup | Good UX, but manual backup is sufficient for v1. |
| Backup to iCloud / Google Drive directly | Requires cloud auth which contradicts current product constraints. Manual share to Drive works fine. |
| Selective restore (pick specific trips) | Adds significant complexity. Full restore is correct for v1. |
| Backup encryption (password protection) | Nice to have. The backup file contains no credentials. Defer unless legal requires it. |
| Backup format migration bridge (old schema → new schema) | Only needed when v18+ ships. Build it at v18 time, not now. |
| Android Auto Backup configuration (`allowBackup`, `fullBackupContent`) | Can enable later after testing; low user awareness currently. |

---

## Summary

**Current state: Zero backup capability.** The app has CSV/PDF export for reporting but nothing that preserves and restores user data. For a local-first, login-free app, this is the single most important trust feature missing before release.

**Recommended path:** Implement Option B (JSON backup/restore) in a single focused sprint (~13–14h). The architecture is clean, the repositories already expose `toMap()` on all models, and `share_plus` is already wired. This is the lowest-risk, highest-user-trust change available right now.

**The one critical implementation detail:** Restore must be a single DB transaction. If it fails mid-way, the user's existing data must be untouched. Do not delete current data before the new data is fully committed.
