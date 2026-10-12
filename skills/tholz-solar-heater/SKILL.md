---
name: tholz-solar-heater
description: >-
  Operate, automate, or debug Tholz SmartHeat solar water heater controllers
  (TSZ1392N and relatives) — the Smart Connect local socket, heating modes
  (ECO/AUT/LIG/DES), setpoint (SPAP) semantics, T1/T2/T3 sensors, support
  relays (apoios), the weekly agenda, and the traps that make "auto mode"
  appear to do nothing. Use when working with Tholz hardware, the tholz Home
  Assistant integration, or solar water heating mode/setpoint automation.
---

# Tholz SmartHeat (solar water heaters with support)

The controller ("CONTROLADOR DE TEMPERATURA PARA AQUECIMENTO SOLAR COM APOIO") runs fully
autonomously — any app/Home Assistant automation is an **overlay** on top of its own logic.
It is solar-first: the collector loop is pump/differential controlled, and the supports
(apoios) are a deliberately guarded backup.

## Hardware shape

- 3× NTC 10K inputs: **T1** collector, **T2** reservoir/pool, **T3** auxiliary (optional; 1ª geração
  devices like the TSZ1392N usually have no T3 installed).
- 3 relays: solar circulation pump, **Apoio 1**, **Apoio 2** — each up to 3000 W @ 220 V /
  1500 W @ 127 V; the manual allows only ONE resistance wired directly to a support output.
- Optional **Smart Connect** dongle: local TCP JSON socket (port 4000) + app/voice control.
- Full parameter tables, screens, and behaviour details: [references/manual-tsz1392n.md](references/manual-tsz1392n.md).

## Mode semantics (what automations get wrong)

| Controller mode | `opMode` | HA name\* | Actual behaviour |
|---|---|---|---|
| DESLIGADO | 0 | `off` | Everything off. With P109 set, auto-returns to AUT after that duration. |
| LIGADO ("all on") | 1 | `performance` | **Manual** simultaneous activation of BOTH supports, ≤ 2 h or until SPAP. If SPAP is already met when set, it can revert to AUTO almost instantly. |
| AUTOMÁTICO | 2 | `heat_pump` | Solar controls active; supports activate **only via weekly agenda events or manual activation**. Auto mode alone heats nothing when no agenda event is active. |
| ECONÔMICO | 3 | `eco` | Solar only + boiler cooling; supports **fully disabled** (agenda and even manual activation are blocked). |

\* HA water-heater entities may only use HA's fixed mode vocabulary, so the integration maps
Tholz's names onto it: `heat_pump` = app's "Auto", `performance` = "all on".

The critical separation:

- **SPAP** (`sp`, tenths of °C) is the **supports'** setpoint (quick-adjust key "A"). Supports heat
  toward SPAP; nothing else uses it.
- The **solar pump** is differential-controlled (P101 start / P102 stop) and is **not capped by
  SPAP** — it keeps circulating while the tank is above SPAP. Raising the setpoint does not
  "capture more sun"; it only changes what the supports do.
- **ECO cooling**: only in ECO, when T1−T2 ≤ −4.0 °C and the tank is above P106 (default 50 °C),
  the pump runs to dump heat until the tank drops to P106 — typically overnight. So in ECO a
  tank hotter than ~50 °C gets actively cooled at night; in AUTO it is not.

## Weekly agenda — the usual reason "auto doesn't heat"

- 5 events, each with Liga/Desliga times and per-weekday enables (all days on by default,
  factory event 12:00→23:59); optional "atrelamento" ties both supports to the same times.
- In AUTO, supports fire **per these events** (or manual activation, ≤ 2 h / until SPAP).
- The agenda is **not readable/writable through the local socket** — program it on the
  controller panel (level-3 programming, code 162) or in the app if it supports it.
- An empty/different agenda is indistinguishable from "support broken" via the socket alone;
  check the controller LCD's support-state indicator (item 12) and tank temperature.

## Verify support heating empirically

Relay/output state is **not** proof of heating. The outputs can report `on` and hold there
while the tank does not move: no load wired to that relay, tripped breaker, dead element, or
the element's own thermostat. Watch the **tank temperature** (0.1 °C resolution; ~3 kW ≈
+0.2 °C/min on 200 L) or the LCD support indicator.
If nothing heats: breaker → LCD indicator vs socket state → which relay the installers used →
element/thermostat. Manual writes to the socket outputs are accepted regardless.

## Common parameters (level-2 programming, code 162; factory-reset code 218)

| Parameter | Default | Notes |
|---|---|---|
| P101 ΔT (T1−T2) start pump | 5.0 °C | adjust range: (P102+0.1)..40.0 |
| P102 ΔT (T1−T2) stop pump | 2.5 °C | |
| P103 T1 anti-freeze start | 5.0 °C | fixed 2.0 °C hysteresis |
| P104 T1 overheat stop | 99.9 °C | fixed 2.0 °C hysteresis |
| P105 T2-overheat hysteresis | 2.0 °C | for the SAT2 control below |
| P106 ECO cooling stop temp | 50.0 °C | cooling runs while tank > P106 (ECO only) |
| P109 DES duration | 00:00 | 0 disables; otherwise DES → AUTO after it |
| SAT2 tank "comfort" cap | 70.0 °C | T2 above it stops the solar pump (quick-adjust, key "A") |
| SPAP support setpoint | 42.0 °C | quick-adjust; max limited by P203/P303 (50.0 default) |
| P201 apoio-1 mode | 0 | 0 independent / 1 tied to apoio 2 after P204 |
| P204 max time apoio 1 | 0 | minutes to reach SPAP before the tied one starts; 0 = disabled |
| P301 apoio-2 mode | 0 | 0 thermostat / 1 barrilete recirculation |
| P304/P305 recirc scan/interval | 5 / 15 min | recirculation mode only |
| P404 T3 attachment | 1 | 0 off / 1 reservoir / 2 recirculation (T3 present only) |
| Solar mode AUT1/AUT2 | AUT1 | AUT2 also requires T1 > T3 (only adjustable when P404 = 1) |

## Local socket (Smart Connect dongle)

- TCP port **4000**, plain JSON, **no auth**, only reachable while the dongle has internet.
- Read: `{"command":"getDevice"}`; Write: `{"command":"setDevice","argument":{...}}` where the
  argument is a **whole sub-block snapshot** (e.g. the full `heating` block with your changes),
  not a field-level patch.
- Full field reference, samples, and nuances: [references/socket-protocol.md](references/socket-protocol.md).

## Home Assistant integration notes

- HACS integration `felippepuhle/tholz-hass-integration`; polls the socket (~5 s).
- 1ª geração devices use the flat `heating` block with no `t3`; newer devices use `heatings`
  blocks per circuit. The water-heater `current_temperature` must fall back t3→t2 on 1ª geração
  (fix: `felippepuhle/tholz-hass-integration#97`, carried in fork `dbmrq/tholz-hass-integration`).
- HA services only accept HA mode names (`off`, `performance`, `heat_pump`, `eco`) — not the
  Portuguese names. `min_temp` comes from the device limits (often 40–60 °C).
- You can hide unwanted modes from every HA UI with a `homeassistant: customize:` override of
  the entity's `operation_list` attribute (e.g. keep only `[eco, heat_pump]`).

## Hard-won rules

- Never treat "auto mode" as "heating will happen" — agenda or manual activation is required.
- To guarantee zero backup usage, ECO is the only true state (manual activation is blocked too).
- LIG is a one-shot: it can flip back to AUTO on its own once SPAP is reached — don't assume
  the mode you set sticks; re-check before concluding anything.
- Everything on the socket is tenths of °C; `mode` is the heating *type* (3 = solar residencial),
  not the operation mode.
- The dongle needs internet for local control; losing WAN does not stop the controller itself.
