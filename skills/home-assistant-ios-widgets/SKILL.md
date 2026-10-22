---
name: home-assistant-ios-widgets
description: >-
  Build, edit, back up, and restore Home Assistant companion-app iOS Home
  Screen widgets — custom-widget import JSON, MagicItem actions, server IDs,
  portable fallbacks, dashboard navigation, and the traps that make a tile open
  the app, show a blank page, or vanish after import. Use when changing an iOS
  widget, generating an import file, adopting an app-created widget, or
  debugging widget behaviour.
---

# Home Assistant iOS custom widgets

## The one rule

The companion app's widget import (Settings → Companion App → Widgets → Import)
**replaces every custom widget**. Keep the whole library in one source and
generate one import file; never create per-widget files that get imported
separately.

## Workflow in the HA config repo

- Source of truth: `ios_widgets/registry.yaml`.
- Build: `python3 tools/ios_widgets.py build` (or `make widgets`) → writes
  `www/widgets/ios-widgets.json` and prints the import URL with a semantic
  content hash (`…/local/widgets/ios-widgets.json?v=<hash>`).
- Validate: `python3 tools/ios_widgets.py check` (or `make widgets-check`) —
  checks every entity ID and every `<dashboard>/<view>` path against live HA.
- Back up: `python3 tools/ios_widgets.py backup <app-export.json>` — timestamped
  copy in `ios_widgets/exports/`, prints each widget's item count and every
  `serverId` it contains.
- Adopt an app-created widget:
  `python3 tools/ios_widgets.py convert <app-export.json>` — prints registry
  YAML, folds a `<name> (backup)` twin into `portable_fallback`, and keeps
  unsupported items as `type: raw`.
- Full schema and format notes: `docs/ios-home-widget.md`.

HA serves `/local` with a ~31-day cache. Import the URL the build prints; a bare
path can serve an old file.

## Import file shape

```json
{
  "schemaVersion": 1,
  "exportedPart": "customWidgets",
  "exportedAt": "2026-10-21T16:00:00Z",
  "watchConfigurations": [],
  "legacyComplications": [],
  "complicationConfigurations": [],
  "carPlayConfigurations": [],
  "customWidgets": [],
  "appIconShortcutConfigurations": []
}
```

- `exportedPart: "customWidgets"` selects the widget-only import. All six arrays
  are required by the decoder (empty is fine).
- `CustomWidget`: `id` (stable UUID), `name`, `items`, `itemsStates` (`{}`).
- `MagicItem`: required `id`, `serverId`, `type`; optional `customization`,
  `action`, `tapAction`, `displayText`.
- `Customization.requiresConfirmation` is a required key **inside**
  `customization`. Omitting `customization` makes the widget ask for
  confirmation on every tap.
- `ItemAction` encodes as a single-key object with positional associated values:
  `{"navigate":{"_0":"lovelace-yaml/water-pumps"}}`,
  `{"toggle":{}}`,
  `{"performAction":{"_0":"widget","_1":"homeassistant.toggle","_2":"{\"entity_id\":\"light.x\"}"}}`.

## The traps

| Symptom | Cause | Fix |
|---|---|---|
| Tile opens the app instead of acting | the non-icon area runs `tapAction`, whose entity default is more-info | set both `action` and `tapAction` to `{"toggle":{}}` |
| Dashboard tile is blank | wrong dashboard `url_path` or view path | use `<dashboard url_path>/<view>` (this house: `lovelace-yaml/...`); `check` catches it |
| Widget missing after import | all its items had non-empty server IDs the phone did not know | use empty IDs or the real ID; `backup` prints it |
| Import reports 0 widgets | every item was filtered out | check `exportedPart` and server IDs |
| Every tap asks to confirm | `customization` omitted or `requiresConfirmation: true` | set `requiresConfirmation: false` |
| Icon is blank / generic | MDI name used hyphens or an `mdi:` prefix | underscores only (`water_pump`, `wall_sconce_round`) |

## Server ID and portable fallback

- `serverId` is the app's own server identifier, not an entity. A server added by
  discovery uses HA's instance UUID (`.storage/core.uuid`); manual-URL onboarding
  historically used a random UUID. Any app export shows the real one.
- The importer drops non-empty IDs it does not know and keeps empty ones.
- Entity items with an empty ID are re-pointed by the app's migration, which
  keeps customization but drops `action`/`tapAction`. An `assistPrompt` item is
  never re-pointed — it is the safe carrier for server-independent actions.
- Portable twin: `assistPrompt` + `performAction` with action server ID
  `"widget"`; an unknown action server ID falls back to the only configured
  server. `homeassistant.toggle` works for lights, covers and media players.
  It cannot show live state or state colors.
- `navigate` on an `assistPrompt` is server-independent as well, but use the real
  ID when known so the app opens that server directly.

## Verify on the phone

1. Build, import, then add a **Large** custom widget (12-tile cap; Medium shows 6).
2. Tap a dashboard tile → correct tab; tap a toggle's **name area** → in-place,
   no app launch.
3. Long-press the widget → Edit Widget → enable **Show states** for live text.
4. iOS controls refresh timing (~15 min); a tap refreshes the widget, and silent
   `update_widgets` pushes can nudge it.

## Hard-won rules

- A tile that should run a multi-step scene/automation must target a `script` or
  a template `switch` that wraps it, not the leaf device — a projector tile
  pointing at `media_player.projector` only powers the projector and leaves the
  lights/blinds alone.
- Keep widget IDs stable across builds so re-import updates a placed Home Screen
  widget instead of orphaning it.
- `ui-lovelace.yaml` is not necessarily the `lovelace` dashboard — read
  `lovelace.dashboards` / `get_panels` and use the actual `url_path`.
- Do not put a fixed icon color on a stateful entity tile unless intended; it
  overrides the on/off state color.
- A `raw` registry item is emitted verbatim and is not portable across server IDs.
- Back up the phone's current widgets before the first import that replaces them.
