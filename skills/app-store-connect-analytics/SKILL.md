---
name: app-store-connect-analytics
description: Query App Store Connect analytics data including downloads, purchases, reviews, and sessions. Use when the user asks about app revenue, downloads, user reviews, or wants to analyze app performance metrics.
---

# App Store Connect Analytics

Query App Store Connect for app analytics data including downloads, purchases, customer reviews, and session metrics.

## Prerequisites

Credentials must be configured at `~/.config/app-store-connect/credentials.json`. See the xcode-cloud-ci skill for setup instructions.

Required Python packages: `pip3 install PyJWT requests cryptography`

## Available Commands

```bash
# Get recent downloads (last 30 days by default)
scripts/asc_analytics.py downloads --app "Leio"

# Get purchase/revenue data
scripts/asc_analytics.py purchases --app "Leio"

# Get customer reviews
scripts/asc_analytics.py reviews --app "Leio" --limit 50

# Get session metrics
scripts/asc_analytics.py sessions --app "Leio"

# List all apps
scripts/asc_analytics.py list-apps
```

## Report Types

| Command | Description | Key Metrics |
|---------|-------------|-------------|
| `downloads` | App download statistics | Total downloads, first-time downloads, redownloads |
| `purchases` | In-app purchases and subscriptions | Revenue, proceeds, sales by product |
| `reviews` | Customer reviews and ratings | Rating, title, body, response |
| `sessions` | App usage sessions | Active devices, sessions, engagement |

## Example Workflows

### Analyze Revenue
```bash
# Get purchase breakdown by product
scripts/asc_analytics.py purchases --app "Leio" --days 90

# Output includes: product ID, quantity, sales amount, proceeds
```

### Check User Sentiment
```bash
# Get recent reviews sorted by date
scripts/asc_analytics.py reviews --app "Leio" --limit 50

# Output includes: rating, date, title, body, territory
```

### Track Growth
```bash
# Compare downloads over time
scripts/asc_analytics.py downloads --app "Leio" --days 30
```

## Notes

- Analytics data may have a 24-48 hour delay from App Store Connect
- Revenue data shows proceeds (what you receive) and sales (pre-commission)
- Reviews are fetched from the Customer Reviews API, not analytics reports
- For detailed financial reports, use App Store Connect web interface

## Credentials

Uses the same credentials as xcode-cloud-ci at `~/.config/app-store-connect/credentials.json`.

The API key needs **Admin** or **Finance** role for revenue data, **Developer** role works for downloads and reviews.
