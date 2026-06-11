# Lay Ledger 🥚📒

**Smart poultry assistant** — a daily egg-laying & profitability journal for backyard and small-farm flocks.

Track how many eggs your hens really lay, which breed pays off, the sold-vs-kept split, and your season's money — all in one place.

---

## 1. App Overview

**Problem it solves**
- It's hard to know how many eggs hens actually lay.
- You can't see which breed is worth its feed.
- Eggs for sale vs. for the family get counted "by eye".
- Money over the season slips through the cracks.

**What it does**
- Daily egg log with per-breed lay rate and sold/kept split.
- Sales & expense tracking → net profit by month.
- Lay-rate **drop detection** with actionable recommendations.
- Reports (custom charts) with **PDF export** and share.
- Tasks, calendar, photo log (with compare), history, reminders.

**Architecture** — MVVM, 100% SwiftUI, no third-party dependencies.
- `DataStore` (`ObservableObject`, `@EnvironmentObject`) — single source of truth + all CRUD and analytics.
- `ThemeManager` (`@EnvironmentObject`) — light/dark/system, applied via `preferredColorScheme`.
- Per-screen views are declarative; business logic lives in the store / view models.
- Persistence: one JSON snapshot in the app's Documents directory (auto-saved on every change). Settings via `@AppStorage`.

**Data flow**
```
View ──(intent)──▶ DataStore (mutate @Published) ──▶ PersistenceService (JSON)
  ▲                                   │
  └────────(@Published refresh)───────┘
```

**App flow** — `Splash → Onboarding (first launch only) → Main app`. No login, no account, no profile — fully local & anonymous.

---

## 2. Design System

Warm "eggshell + yolk" palette (exact hex codes in `Theme.swift`):

| Role | Light | Dark |
|------|-------|------|
| Background | `#FFFBEB` / `#FEF6D9` / `#F5ECCB` | `#17140D` / `#1F1B12` / `#262112` |
| Card | `#FFFFFF` | `#221E15` |
| Yolk accent | `#F59E0B` (active `#D97706`, soft `#FBBF24`) | same |
| Money / teal | `#0D9488` / `#14B8A6` / `#5EEAD4` | brightened |
| Status | good `#22C55E` · watch `#F59E0B` · problem `#EF4444` | brightened |
| Text | `#422006` / `#78622C` / `#A8915C` | warm whites |

- **Typography:** rounded system font via `Font.ll(size:weight:)`.
- **Components** (`Components.swift`): `LLButton`, `Card`, `StatTile`, `StatusBadge`, `LabeledTextField/NumberField/Multiline`, `LLSegmented`, `StepperField`, `EmptyStateView`, `ToastView`, `EggShape`.
- **Charts** (`ChartViews.swift`): custom `LineChartView`, `BarChartView`, `SplitBar`, `RingProgress` — built from `Path`/`Shape` (iOS-14-safe; no Swift Charts).
- Colors are dynamic (`UIColor(dynamicProvider:)`) so a single theme toggle recolors the whole app instantly.

---

## 3–8. Source Map

| Area | Files |
|------|-------|
| Entry / root | `LayLedgerApp.swift`, `ContentView.swift` (RootView coordinator) |
| Splash | `LaunchView.swift` (3 animated layers, single-timer coordinator, full cleanup on disappear) |
| Onboarding | `OnboardingView.swift` (tap-burst · drag · parallax) |
| Shell | `MainTabView.swift` (custom floating tab bar) |
| Models / logic | `Models.swift`, `DataStore.swift`, `Persistence.swift` |
| Services | `NotificationService.swift`, `PDFExportService.swift`, `UIKitBridges.swift` |
| Design system | `Theme.swift`, `Components.swift`, `ChartViews.swift` |
| Screens | `DashboardView`, `FlocksView`, `BreedsView`, `EggLogView`, `LedgerViews` (Sales/Expenses/AddRecord/Details), `ReportsView`, `TasksView`, `CalendarView`, `PhotosView`, `HistoryView`, `RecommendationsView`, `NotificationsView`, `SettingsView` |

Every control is wired: theme & units recolor/reformat the app immediately, notifications call `UNUserNotificationCenter`, photos use PHPicker, reports render a real PDF via `UIGraphicsPDFRenderer`, and all add/edit/delete actions mutate the store and persist.

---

## 9. Build Instructions

**Requirements**
- Xcode 15 or newer (built & verified with Xcode 16.4).
- iOS **14.0+** deployment target.
- No Swift Package / CocoaPods dependencies.

**Run**
1. Open `LayLedger.xcodeproj` in Xcode.
2. Select the **LayLedger** scheme and any iPhone simulator (iPhone SE → 16 Pro Max).
3. Press **Run** (⌘R).

On first launch the app seeds realistic sample data (2 flocks, 4 breeds, ~3 weeks of egg entries with a recent lay-rate dip, sales/expenses, tasks) so every screen and chart is populated immediately. Delete the app to reset.

**Command line**
```bash
xcodebuild -project LayLedger.xcodeproj -scheme LayLedger \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

**Notes**
- Notifications: tap *Save Notifications* on the Reminders screen to grant permission and schedule real local notifications.
- Photo picking requires the simulator/device photo library (usage strings are in `Info.plist`).
