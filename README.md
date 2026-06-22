# Budgetapp

A private, offline-first personal budgeting app for iOS — native Swift + SwiftUI,
with a calm "annotated ledger" feel. Manual tracking, CSV/PDF statement import
with column mapping and a review queue, a rules engine, per-category budgets, and
useful reports. **No backend, no login, no analytics. All data stays on device**
unless you explicitly export it.

## Requirements

- **Xcode 16+** (the project uses file-system–synchronized groups)
- **iOS 17+** (SwiftData)

## Getting started

```bash
open Budgetapp.xcodeproj
```

Select the **Budgetapp** scheme and run on an iOS 17+ simulator. On first launch
the app seeds a sensible set of categories, accounts, and import rules.

Run the tests with **⌘U**, or:

```bash
xcodebuild test -scheme Budgetapp -destination 'platform=iOS Simulator,name=iPhone 15'
```

## Architecture

Layered, with pure logic kept free of SwiftData so it is fast to test.

```
Budgetapp/
  Models/         SwiftData @Model types + shared enums
  Persistence/    ModelContainer, seed data, preview data
  Import/         CSV parser, column mapping, PDF text parser, ImportService
  Services/       RulesEngine, BudgetCalculator, Deduplication,
                  RecurringDetector, ReportsCalculator, Backup
  DesignSystem/   Theme, typography, colour, haptics
  Utilities/      Currency formatting, settings, date helpers, lookups
  Views/          Home, Transactions, Categories, Accounts, Recurring,
                  Rules, Review, Import, Reports, Settings, Components
BudgetappTests/   Unit + integration tests
SampleData/       Example CSVs for trying the importer
```

### Key design choices

- **SwiftData** for persistence. Entities reference each other by `UUID`
  (`categoryId`, `accountId`, …) which keeps the import/dedupe pipeline simple and
  matches the data-model spec.
- **Pure value-type core.** Parsing (`CSVParser`, `PDFStatementParser`,
  `ValueParsing`), the `RulesEngine`, `DeduplicationService`, `BudgetCalculator`,
  and `ReportsCalculator` all operate on plain structs / protocols, so they are
  unit-tested without a live store. SwiftData models adapt into those types
  (e.g. `ImportRule.spec`, `Transaction: BudgetTransactionConvertible`).
- **Import pipeline:** file → parse → column-map → rules → dedupe → preview →
  commit. Every row is shown before anything is saved.

## Features

- **Home** — safe-to-spend-per-day instrument, watch-list categories, review
  banner, upcoming recurring, recent activity.
- **Transactions** — add/edit/delete, search, filter (category/account/type/
  source/date), bulk move & mark-reviewed, swipe actions.
- **Categories** — budgets, spend/remaining/percentage, reorder, archive.
- **Statement import (CSV + PDF)** — flexible CSV column mapping; text-based PDF
  table extraction with running-balance direction inference; duplicate detection;
  rules applied automatically; uncertain rows sent to review. Scanned/image-only
  PDFs fail gracefully with a clear message (OCR is intentionally not included).
- **Rules engine** — priority-ordered, first match wins; matches merchant /
  description / amount / account by contains / equals / startsWith / regex; can set
  category and optionally account. Create a rule straight from a reviewed item.
- **Review queue** — one-tap category chips; assign-and-make-a-rule; reviewed
  items leave the queue.
- **Accounts** — bank / card / cash / wallet with live balances from transactions.
- **Recurring** — add/edit, upcoming view, active/inactive, plus auto-detection
  of likely recurring charges from history.
- **Reports** — income vs expenses, 6-month flow chart, spend by category,
  recurring load, unusual activity.
- **Data safety** — JSON backup + restore, CSV export, confirmable destructive
  actions, debug-only reset/sample-data tools.

## Trying the importer

`SampleData/` contains two CSVs — one with separate debit/credit columns and one
with a signed amount column. Add either to the Files app (or drag into the
simulator) and import via the **Import** tab to exercise mapping → preview →
rules → save.

## Privacy

The app makes no network requests. There is no account system, no telemetry, and
no third-party SDKs. Backups are plain files you generate and share yourself.
