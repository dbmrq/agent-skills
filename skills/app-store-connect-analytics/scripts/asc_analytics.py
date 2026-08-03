#!/usr/bin/env python3
"""
App Store Connect Analytics - Query downloads, purchases, reviews, and sessions.

Usage:
    asc_analytics.py <command> [options]

Commands:
    list-apps           List all apps
    downloads           Get download statistics
    purchases           Get purchase/revenue data
    reviews             Get customer reviews
    sessions            Get session metrics

Options:
    --app NAME          Filter by app name (required for most commands)
    --days N            Number of days to query (default: 30)
    --limit N           Number of items to return (default: 25)

Credentials are read from ~/.config/app-store-connect/credentials.json
"""

import argparse
import gzip
import json
import sys
from datetime import datetime, timedelta, timezone
from io import BytesIO
from pathlib import Path

try:
    import jwt
    import requests
except ImportError:
    print("Error: Required packages not installed.", file=sys.stderr)
    print("Run: pip3 install PyJWT requests", file=sys.stderr)
    sys.exit(1)

CREDENTIALS_PATH = Path.home() / ".config" / "app-store-connect" / "credentials.json"
API_BASE = "https://api.appstoreconnect.apple.com/v1"


def load_credentials():
    """Load API credentials from config file."""
    if not CREDENTIALS_PATH.exists():
        print(f"Error: Credentials not found at {CREDENTIALS_PATH}", file=sys.stderr)
        sys.exit(1)
    
    with open(CREDENTIALS_PATH) as f:
        creds = json.load(f)
    
    key_path = Path(creds["private_key_path"]).expanduser()
    with open(key_path) as f:
        creds["private_key"] = f.read()
    
    return creds


def generate_token(creds):
    """Generate a JWT token for App Store Connect API."""
    now = datetime.now(timezone.utc)
    payload = {
        "iss": creds["issuer_id"],
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=20)).timestamp()),
        "aud": "appstoreconnect-v1"
    }
    return jwt.encode(payload, creds["private_key"], algorithm="ES256",
                      headers={"kid": creds["key_id"]})


def api_get(endpoint, token, params=None):
    """Make an authenticated GET request."""
    headers = {"Authorization": f"Bearer {token}"}
    resp = requests.get(f"{API_BASE}{endpoint}", headers=headers, params=params)
    resp.raise_for_status()
    return resp.json()


def get_apps(token):
    """Get all apps."""
    data = api_get("/apps", token, {"limit": 200})
    return data.get("data", [])


def find_app(token, name):
    """Find an app by name."""
    apps = get_apps(token)
    for app in apps:
        if name.lower() in app["attributes"]["name"].lower():
            return app
    return None


def get_reviews(token, app_id, limit=25):
    """Get customer reviews for an app."""
    data = api_get(f"/apps/{app_id}/customerReviews", token,
                   {"limit": limit, "sort": "-createdDate"})
    return data.get("data", [])


def get_analytics_report_request(token, app_id):
    """Get or find existing analytics report request."""
    data = api_get("/analyticsReportRequests", token, {
        "filter[app]": app_id,
        "filter[accessType]": "ONGOING"
    })
    requests_list = data.get("data", [])
    return requests_list[0] if requests_list else None


def get_analytics_reports(token, request_id, category):
    """Get analytics reports for a category."""
    data = api_get(f"/analyticsReportRequests/{request_id}/reports", token,
                   {"filter[category]": category})
    return data.get("data", [])


def download_report_data(token, report_id):
    """Download and decompress report data."""
    # Get instances
    instances = api_get(f"/analyticsReports/{report_id}/instances", token)
    if not instances.get("data"):
        return []

    instance = instances["data"][0]
    segments = api_get(f"/analyticsReportInstances/{instance['id']}/segments", token)
    if not segments.get("data"):
        return []

    segment = segments["data"][0]
    url = segment["attributes"]["url"]

    # Download gzipped data
    resp = requests.get(url)
    with gzip.GzipFile(fileobj=BytesIO(resp.content)) as f:
        content = f.read().decode("utf-8")

    # Parse TSV
    lines = content.strip().split("\n")
    if len(lines) < 2:
        return []

    headers = lines[0].split("\t")
    rows = []
    for line in lines[1:]:
        values = line.split("\t")
        rows.append(dict(zip(headers, values)))
    return rows


def cmd_list_apps(token, args):
    """List all apps."""
    apps = get_apps(token)
    print("Apps:")
    for app in apps:
        attrs = app["attributes"]
        print(f"  - {attrs['name']} ({attrs['bundleId']})")


def cmd_reviews(token, args):
    """Get customer reviews."""
    app = find_app(token, args.app)
    if not app:
        print(f"App '{args.app}' not found")
        return 1

    reviews = get_reviews(token, app["id"], args.limit)
    print(f"Reviews for {app['attributes']['name']} ({len(reviews)} results):\n")

    for r in reviews:
        attrs = r["attributes"]
        rating = "★" * attrs["rating"] + "☆" * (5 - attrs["rating"])
        print(f"{rating}  {attrs.get('createdDate', '')[:10]}  {attrs.get('territory', '')}")
        if attrs.get("title"):
            print(f"  {attrs['title']}")
        if attrs.get("body"):
            body = attrs["body"][:200] + "..." if len(attrs["body"]) > 200 else attrs["body"]
            print(f"  {body}")
        print()


def cmd_downloads(token, args):
    """Get download statistics."""
    app = find_app(token, args.app)
    if not app:
        print(f"App '{args.app}' not found")
        return 1

    req = get_analytics_report_request(token, app["id"])
    if not req:
        print("No analytics report request found. Create one in App Store Connect.")
        return 1

    reports = get_analytics_reports(token, req["id"], "APP_USAGE")
    download_report = next((r for r in reports
                           if "Download" in r["attributes"]["name"]), None)
    if not download_report:
        print("No download report available")
        return 1

    data = download_report_data(token, download_report["id"])
    print(f"Downloads for {app['attributes']['name']} (last {args.days} days):\n")

    total = sum(int(row.get("Total Downloads", row.get("totalDownloads", 0)))
                for row in data[-args.days:])
    print(f"Total downloads: {total:,}")


def cmd_purchases(token, args):
    """Get purchase/revenue data."""
    app = find_app(token, args.app)
    if not app:
        print(f"App '{args.app}' not found")
        return 1

    req = get_analytics_report_request(token, app["id"])
    if not req:
        print("No analytics report request found")
        return 1

    reports = get_analytics_reports(token, req["id"], "COMMERCE")
    purchase_report = next((r for r in reports
                           if "Purchase" in r["attributes"]["name"]), None)
    if not purchase_report:
        print("No purchase report available")
        return 1

    data = download_report_data(token, purchase_report["id"])
    print(f"Purchases for {app['attributes']['name']}:\n")

    # Aggregate by product
    by_product = {}
    for row in data:
        pid = row.get("Product Identifier", row.get("productIdentifier", "unknown"))
        qty = int(row.get("Quantity", row.get("quantity", 0)))
        proceeds = float(row.get("Proceeds", row.get("proceeds", 0)))
        if pid not in by_product:
            by_product[pid] = {"qty": 0, "proceeds": 0}
        by_product[pid]["qty"] += qty
        by_product[pid]["proceeds"] += proceeds

    for pid, stats in sorted(by_product.items(), key=lambda x: -x[1]["proceeds"]):
        print(f"  {pid}: {stats['qty']} purchases, ${stats['proceeds']:.2f}")


def cmd_sessions(token, args):
    """Get session metrics."""
    app = find_app(token, args.app)
    if not app:
        print(f"App '{args.app}' not found")
        return 1

    req = get_analytics_report_request(token, app["id"])
    if not req:
        print("No analytics report request found")
        return 1

    reports = get_analytics_reports(token, req["id"], "APP_USAGE")
    session_report = next((r for r in reports
                          if "Session" in r["attributes"]["name"]), None)
    if not session_report:
        print("No session report available")
        return 1

    data = download_report_data(token, session_report["id"])
    print(f"Sessions for {app['attributes']['name']} (last {args.days} days):\n")

    recent = data[-args.days:] if len(data) > args.days else data
    total_sessions = sum(int(row.get("Sessions", row.get("sessions", 0))) for row in recent)
    print(f"Total sessions: {total_sessions:,}")


def main():
    parser = argparse.ArgumentParser(description="App Store Connect Analytics")
    parser.add_argument("command", choices=["list-apps", "downloads", "purchases",
                                            "reviews", "sessions"])
    parser.add_argument("--app", help="App name to query")
    parser.add_argument("--days", type=int, default=30, help="Days to query")
    parser.add_argument("--limit", type=int, default=25, help="Results limit")
    args = parser.parse_args()

    creds = load_credentials()
    token = generate_token(creds)

    commands = {
        "list-apps": cmd_list_apps,
        "downloads": cmd_downloads,
        "purchases": cmd_purchases,
        "reviews": cmd_reviews,
        "sessions": cmd_sessions,
    }

    if args.command != "list-apps" and not args.app:
        print("Error: --app is required for this command", file=sys.stderr)
        return 1

    return commands[args.command](token, args) or 0


if __name__ == "__main__":
    sys.exit(main())

