# Travel Expenses: UX Principles

## Core UX Philosophy

**Calm, Focused, Zero Friction**

Users should feel confident and in control when tracking expenses. The app removes obstacles; it doesn't create busywork or confusion.

---

## Guiding Principles

### 1. Minimize Cognitive Load
- **One screen per task** – don't sprawl complex operations across multiple dialogs
- **Clear state feedback** – loading states, success confirmations, error messages are unambiguous
- **Familiar patterns** – use Material Design conventions; don't reinvent controls
- **No hidden features** – discoverability through clear labels and intuitive workflows

### 2. Offline-First UX
- **No "requires internet" errors** – the app works completely offline
- **No connection indicators** – users don't need to think about sync status
- **Graceful data persistence** – changes save locally immediately
- **No artificial "save" buttons** – the app auto-saves in the background

### 3. Traveler-Centric Context
- **Trip-focused mental model** – "I'm in Paris, logging expenses" not "I'm in a transaction database"
- **Currency awareness** – show the trip's native currency; exchange rates are visible when relevant
- **Date context** – trips span date ranges, not calendar months
- **Manual entry** – no forced receipts, screenshots, or photo uploads

### 4. Premium Simplicity
- **Visual restraint** – remove decoration, icons, and visual noise
- **Typography hierarchy** – clear difference between headings, labels, and content
- **Ample white space** – breathing room between elements
- **Purposeful color** – colors communicate state (success, error, neutral), not personality

---

## What We Avoid

### No Dashboards
- ❌ No widget-based home screen
- ❌ No overview cards summarizing "total spent", "top categories", etc.
- ❌ No charts or graphs competing for attention
- ❌ Entry point is a **simple trips list** with the current trip highlighted

### No Visual Noise
- ❌ No animations for trivial actions (button taps, screen transitions)
- ❌ No micro-interactions designed to "delight"
- ❌ No illustrations or decorative imagery (except trip backgrounds)
- ❌ No emoji or playful tone (clear and direct instead)

### No Engagement Patterns
- ❌ No notifications or reminders
- ❌ No "streak" counters or achievements
- ❌ No social features or sharing
- ❌ No "encourage more logging" dark patterns

### No Enterprise/Admin UX
- ❌ No complex filtering, sorting, or advanced search
- ❌ No bulk operations or batch workflows
- ❌ No user roles or permission management
- ❌ No audit logs or admin panels

---

## Calm Interaction Patterns

### Adding an Expense
1. **Tap "+" button** on trips list
2. **Fill simple form**:
   - Amount (numeric, auto-focus)
   - Currency (trip default, tap to change)
   - Category (dropdown, 5-8 categories)
   - Description (optional, one-liner)
   - Date (defaults to today)
3. **Tap save** → returns to expense list with confirmation

**Principles**:
- ✅ Fast entry (90% of expenses logged in <15 seconds)
- ✅ Sensible defaults (trip currency, today's date)
- ✅ No hidden fields or advanced options
- ✅ Immediate feedback (expense appears in list)

### Viewing a Trip
1. **Tap trip** from list
2. **See**:
   - Trip title and date range
   - Total spending (by category, by currency)
   - List of expenses (scrollable, reverse chronological)
3. **Actions** (swipe or long-press):
   - Edit expense
   - Delete expense
   - View details

**Principles**:
- ✅ One view for all trip context
- ✅ Expenses immediately visible
- ✅ Multi-currency totals show breakdown
- ✅ No deep navigation; go back returns to trips list

### Exporting a Report
1. **Open trip** → "Export" button
2. **Choose format** (PDF or CSV)
3. **Report generates** → share or save
4. **Done**

**Principles**:
- ✅ One-tap export
- ✅ Professional, clean output
- ✅ Works offline (generates locally)
- ✅ No configuration or options dialog

---

## Loading and Error States

### Loading State
- **Context-appropriate**: Use a simple spinner if <1 second expected; show progress if >1 second
- **No blocking**: Skeleton screens or shimmer preferred over full-screen spinners
- **Specific to action**: Don't show "Loading..." for the entire app; show it only for the operation in progress

### Error State
- **Clear messages**: "Internet not available" not "Error code: ERR_NO_CONN"
- **Actionable**: Offer a retry button or suggest the next step
- **Non-intrusive**: Error alerts appear inline, not as full-screen modals
- **Recoverable**: Users never see an error with no way to recover

### Empty State
- **Contextual**: "No expenses yet. Tap + to add your first expense."
- **Encouraging**: Suggest the next action without being pushy
- **Visual feedback**: Icon or simple illustration, not empty void

---

## Localization UX

### Arabic (RTL) Support
- **Layout mirrors** (buttons, lists, inputs right-align)
- **Text direction** respects language context
- **Input fields** support Arabic numerals and text entry
- **Consistent typography** (Cairo font maintains readability)

### English (LTR) Support
- **Standard Material layout**
- **Western typography** (Inter font)
- **Familiar interaction patterns**

### Locale Switching
- **Settings → Language** → Toggle Arabic/English
- **App rebuilds** with appropriate layout and text
- **State persists** (next launch uses selected language)

---

## Accessibility

### Mobile-First
- **Touch targets** ≥ 48dp (Material spec)
- **Font sizes** readable at arm's length
- **Contrast** meets WCAG AA standard (4.5:1 for text)

### Readable Typography
- **Headings**: 24-28sp, semibold
- **Body text**: 14-16sp, regular
- **Labels**: 12sp, medium (not light)

### Semantic HTML/Widgets
- **Button labels** are descriptive ("Delete trip" not "OK")
- **Form fields** have associated labels
- **Screen readers** understand hierarchy and relationships

---

## Performance and Responsiveness

### Immediate Feedback
- **Taps register instantly** (no input lag)
- **Lists scroll smoothly** (60fps target)
- **Transitions complete quickly** (<300ms for route changes)

### Data Loading
- **SQLite queries complete fast** (< 100ms typical for in-app data)
- **UI never freezes** while database operations execute
- **Long operations** show progress without blocking user

### Battery and Data
- **No background syncing** (offline-first, no cloud)
- **No battery drain** from timers or polling
- **Minimal battery usage** from simple, event-driven UI

---

## Color and Visual Design

### Color Palette
- **Primary**: App brand color (used sparingly)
- **Accent**: Highlights important actions (confirm, delete)
- **Neutral**: Grays for UI chrome (dividers, disabled states)
- **Semantic**: Green for success, red for errors, orange for warnings

### Visual Hierarchy
1. **Headings** – dominant, sets context
2. **Body content** – main focus
3. **Secondary info** – supporting details (amounts, dates)
4. **UI chrome** – buttons, dividers (minimize visual weight)

### Whitespace
- **Breathing room** between sections
- **List items** have vertical padding (12-16dp)
- **Form fields** have margin (8-12dp)
- **No visual clutter** from unnecessary borders or backgrounds

---

## Form Design

### Input Fields
- **Single column** on mobile (no side-by-side)
- **Full width** with appropriate padding
- **Visible labels** above each field
- **Placeholder text** is optional; label is primary

### Validation
- **Real-time feedback** (as user types, not after submit)
- **Clear error messages** ("Amount must be greater than 0")
- **Red highlight** on invalid field
- **Disable submit** if form is invalid

### Dropdowns/Selectors
- **Large tap targets** for options
- **Scrollable if >5 options**
- **Initial value** shown by default
- **Cancel option** to close without selecting

---

## Navigation

### Information Architecture
- **Home**: Trips list (current trip highlighted)
- **Trip**: Expenses for that trip (create, view, edit, delete)
- **Settings**: Language, currency, default category
- **Reports**: Export options, past exports

### Navigation Flow
- **Minimize nesting** – avoid >3 levels deep; most common workflows are ≤2 taps from home
- **Back button** always returns to previous context
- **No modal stacking** – close current dialog before opening another
- **Consistent back gesture** (swipe on iOS, system back on Android)

---

## Testing UX

### Manual Testing Checklist
- [ ] All text is readable (font size, contrast)
- [ ] Touch targets are ≥ 48dp
- [ ] Loading states appear quickly and don't block
- [ ] Error messages are clear and actionable
- [ ] Empty states suggest next steps
- [ ] RTL layout is correct in Arabic mode
- [ ] No visual jank or frame drops during scrolling
- [ ] Offline: app works without internet
- [ ] Back button behavior is consistent
- [ ] Accessibility labels are present for screen readers

---

## Decision Framework

When designing or evaluating a feature:

1. **Does it reduce friction?** (or add complexity?)
2. **Does it respect the traveler's context?** (or feel generic?)
3. **Is it calm and focused?** (or busy and overwhelming?)
4. **Does it work offline?** (or require cloud?)
5. **Could a new user figure it out alone?** (or is it hidden?)

If all are true → implement it. If any are false → reconsider or redesign.
