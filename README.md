# Tanay Budget

Native, offline-first iOS budgeting app built with SwiftUI and SwiftData.

## Architecture

- `Models`: SwiftData entities plus import draft models.
- `Persistence`: local model container setup.
- `Services`: budget math, CSV/PDF import, rules, deduping, recurring detection, seed data, and backup/export.
- `Views`: SwiftUI feature modules for Home, Ledger, Import, Review, Reports, setup, and data safety.
- `BudgetAppTests`: focused XCTest coverage for parsing, rules, dedupe, budget math, and import review transitions.

## Run

Open `BudgetApp.xcodeproj` in Xcode 15 or newer, choose an iOS 17+ simulator, and run the `BudgetApp` scheme.

Command line, once Xcode command line tools are active:

```sh
xcodebuild -project BudgetApp.xcodeproj -scheme BudgetApp -destination 'platform=iOS Simulator,name=iPhone 15' test
```

## Import Sample

Use `Samples/sample-transactions.csv` from the iOS simulator Files app to exercise CSV mapping, preview, rules, dedupe, and the review queue.
