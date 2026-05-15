# Travel Expenses: Product Principles

## Core Philosophy

**Calm, Premium Simplicity for Travelers**

Travel Expenses is designed for travelers who need to track and manage expenses with minimal cognitive load. We optimize for clarity, reliability, and peace of mind—not feature density or engagement metrics.

---

## Primary User Intent

Users want to:
- **Track expenses** during trips without friction
- **Understand spending patterns** across trips and currencies
- **Export clean reports** for personal finance or reimbursement
- **Stay in control** with offline-first operation

Users do **not** want:
- Dashboard dashboards with overwhelming visualizations
- Notifications trying to "engage" them
- Third-party data sharing or analytics
- Complex onboarding or hidden features

---

## Traveler-First Decisions

### Multi-Currency by Default
- Trips span multiple countries → support native currency tracking
- Exchange rates are context-specific (vary per trip, per day)
- No global exchange rate service dependency
- Manual rate entry when needed, intelligent defaults when possible

### Offline-First Operation
- Trips work completely offline
- Data syncs locally to SQLite v15
- No cloud dependency, no login required
- Users own their data entirely

### Calm Trip Management
- **One active trip** per context (simplifies mental model)
- **Flexible date ranges** (not just calendar months)
- **Manual entry for control** (no SMS parsing unless user opts in)
- **No pressure to log immediately** (trips persist for weeks/months)

---

## What We Don't Build

### No Analytics
- No telemetry, no usage tracking, no "anonymized" data collection
- No A/B testing of features
- User data never leaves their device

### No Fake Engagement
- No streak counters, badges, or gamification
- No daily reminders or push notifications
- No "encourage you to log more" dark patterns

### No Unnecessary Complexity
- No savings goals, budgets, or forecasts (focused on tracking reality, not behavior change)
- No investment tracking or portfolio features (separate product domain)
- No team collaboration or shared trip management (individual traveler focus)

---

## Success Metrics (Internal)

- **Reliability**: No data loss, no crashes during trips
- **Simplicity**: New users can log an expense within 30 seconds
- **Offline**: Works completely without internet
- **Export Quality**: Reports are clean, professional, correct
- **Maintainability**: Code is pragmatic, not over-architected

---

## Premium Simplicity Standard

Every feature decision must pass these gates:

1. **Does it solve a real traveler problem?** (or is it "nice to have"?)
2. **Does it add cognitive load or reduce it?**
3. **Can it work completely offline?**
4. **Is the implementation pragmatic or over-engineered?**
5. **Does it respect user privacy?**

If a feature doesn't pass all five, it's deferred or rejected.

---

## Roadmap Philosophy

Phases are **stability first, then depth**:
- **Phase 1**: Stabilize core tracking and reporting
- **Phase 2**: Improve trip insights (spending by category, per-day analysis)
- **Phase 3**: Smart exchange rate handling and currency prediction
- **Phase 4**: Cross-trip analytics and historical patterns (still local-only)

Future "Phase X" decisions (cloud, sharing, advanced features) require explicit user opt-in and zero data sharing without consent.
