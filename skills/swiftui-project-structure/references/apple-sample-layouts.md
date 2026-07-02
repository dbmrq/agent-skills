# Apple Sample Project Layouts

Canonical folder patterns from Apple’s SwiftUI sample repos. Use these as templates — not the article’s generic `Features/Home/HomeViewModel.swift` tree with a global `Models/` folder.

## Backyard Birds (`sample-backyard-birds`)

**Repo root** — app code, packages, and extensions are siblings:

```
Backyard Birds/
├── Backyard Birds.xcodeproj
├── Multiplatform/              # Main app sources (shared across iOS/macOS/etc.)
│   ├── BackyardBirdsApp.swift
│   ├── ContentView.swift
│   ├── Navigation/
│   ├── General/              # Cross-cutting helpers
│   ├── Account/
│   ├── Backyards/
│   ├── Birds/
│   ├── Plants/
│   ├── Shop/
│   ├── Assets.xcassets
│   └── Localizable.xcstrings
├── BackyardBirdsData/        # SPM — SwiftData models, persistence
├── BackyardBirdsUI/          # SPM — reusable SwiftUI UI
├── LayeredArtworkLibrary/    # SPM — artwork assets
├── Widgets/                  # Widget extension target
├── Watch/                    # watchOS target
└── Configuration/
```

**Feature folder example — `Multiplatform/Birds/`** (views only, no `ViewModels/` subfolder):

```
Birds/
├── BirdsNavigationStack.swift
├── BirdGridItem.swift
├── BirdsSearchResults.swift
├── BirdsSearchSuggestions.swift
├── BirdFoodHappinessIndicator.swift
└── NewBirdIndicator.swift
```

**Takeaways:**
- Domain-named folders at the app source root (`Birds/`, not `Features/Birds/Views/`).
- `Navigation/` and `General/` for app-wide concerns.
- Data and reusable UI live in **packages**, not scattered `Services/` folders in the app target.

## Food Truck (`sample-food-truck`)

**Repo root:**

```
Food Truck/
├── Food Truck.xcodeproj
├── App/                      # Main app target sources
│   ├── App.swift
│   ├── Navigation/
│   ├── General/
│   ├── Account/
│   ├── City/
│   ├── Donut/
│   ├── Orders/
│   ├── Store/
│   ├── Truck/
│   └── Assets.xcassets
├── FoodTruckKit/             # SPM — models, business logic, resources
│   └── Sources/
│       ├── Model/
│       ├── Order/
│       ├── Store/
│       ├── Donut/
│       ├── Truck.swift
│       ├── Account/
│       └── Resources/
└── Widgets/
```

**Feature folder example — `App/Orders/`:**

```
Orders/
├── OrdersView.swift
├── OrdersTable.swift
├── OrderRow.swift
├── OrderDetailView.swift
└── OrderCompleteView.swift
```

**Takeaways:**
- Same domain-folder pattern under `App/`.
- `FoodTruckKit` holds **models and logic**; app target holds **screens and navigation**.
- `FoodTruckModel` (observable aggregate) lives in the kit; views in `App/` observe it via environment.

## Comparison to generic “layer-first” templates

| Generic template (avoid as default) | Apple sample pattern |
|-------------------------------------|----------------------|
| `Models/User.swift` globally | Model types in `*Kit` package or feature-scoped types |
| `ViewModels/HomeViewModel.swift` | Observable model/store + views in `Home/` |
| `Features/Home/Components/` only | Flat domain folder with all feature Swift files |
| `Services/NetworkService.swift` at app root | Clients in kit package; injection at `App` |

## Scaling beyond samples

When the app outgrows one target but does not yet need many packages:

1. Keep **one folder per domain** under the main source root.
2. Extract a package when a **second target** (widget, watch, CLI) needs the same module.
3. Split an oversized domain (e.g. `Store/` with 40 files) into subdomains (`Store/Catalog/`, `Store/Checkout/`) — still feature-first, not `Views/` + `Models/`.
