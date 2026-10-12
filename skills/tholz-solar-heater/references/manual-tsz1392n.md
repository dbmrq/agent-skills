# Tholz TSZ1392N "SmartHeat" — manual extract

Organized extract of the official manual "CONTROLADOR DE TEMPERATURA PARA AQUECIMENTO SOLAR
COM APOIO" (TSZ1392N – 90~240 VCA – P806; VER. 1.2, JULHO/2023). Kept in the original
Portuguese terminology for parameter/screen names, distilled to what integrates and
automations need.

## 1–2. Characteristics & specifications

- Controls solar circulation by temperature differential (T1−T2) between collectors and
  reservoir, and supplements heating with supports (apoios) in pre-programmed time windows.
  Includes anti-freeze and overheat protection; optional barrilete recirculation.
- 3 NTC inputs, 3 relay outputs (pump + 2 supports). Supply 90–240 VAC; 0.1 °C resolution;
  IP53; ≈210 g.
- Relay ratings: pump 1/4 CV @ 220 V; each support up to 1 CV / 3000 W @ 220 V (1500 W @ 127 V).
- **Only one resistance may be wired directly to a support output** (≤3000 W @220 V /
  ≤1500 W @127 V).
- Sensors: NTC 10K, 1 %, B3435/25 °C. T1 collector (−19.9..150 °C), T2 reservoir/pool
  (−19.9..99.9 °C), T3 auxiliary (−19.9..99.9 °C). Sensor cables extendable to 200 m.

## 3. Display & keys

Keys: increment; program ("P"); decrement; "M" (manual switching); "A" (quick setpoints);
clock programming. Indicators: support operation mode, pump operation mode, main/secondary
displays, pump state, supports state, controller signals.

## 5–6. Temperature records & views

- Short-press increment / decrement to view recorded max/min or current temperatures per
  sensor. T3 is only shown when enabled. Records reset daily at midnight; long-press
  increment on the records screen to clear ("CLR REGS").

## 7. Manual activation (acionamento manual)

- "M" menu toggles manual on/off for the circulation pump, Apoio 1 and Apoio 2. Shortcuts from
  the main screen: hold "M" 4 s = pump, hold increment 4 s = Apoio 1, hold decrement 4 s =
  Apoio 2; repeat the hold to return to automatic.
- Manual activation of a support lasts **at most 2 hours or until SPAP is reached**.

## 8. Level-1 programming (user) — key "A"

- **8.1 Quick adjust**: `SPAP` (support setpoint; factory 42.0 °C; range 0.0 .. P203/P303) and
  `SAT2` (T2 overheat to stop the pump — the tank "comfort" cap; factory 70.0 °C;
  −19.9..99.9 °C; hysteresis = P105).
- **8.2 Control mode** (factory Aut): `ECO` (economical), `AUT` (automatic), `LIG` (supports
  manually on), `DES` (off).
- **8.3 Clock/schedule**: time and weekday.

## 9. Level-2 programming (hold "P"; protection code 162; 218 = factory reset)

### Solar block (P1)

| Param | Meaning | Factory |
|---|---|---|
| P101 | ΔT (T1−T2) to START the circulation pump | 5.0 °C (range P102+0.1..40.0) |
| P102 | ΔT (T1−T2) to STOP the pump | 2.5 °C (range 1.0..P101−0.1) |
| P103 | T1 anti-freeze temperature to START the pump (fixed 2.0 °C hysteresis) | 5.0 °C |
| P104 | T1 overheat to STOP the pump (fixed 2.0 °C hysteresis) | 99.9 °C |
| P105 | Hysteresis of the T2 overheat (SAT2) pump control | 2.0 °C |
| P106 | Temperature to STOP eco-mode boiler cooling | 50.0 °C |
| — | Preferred display (DIF/T1/T2/T3) | T-3 |
| — | Solar operation mode AUT1 / AUT2 (matters only when P404 = 1) | AUT1 |
| P109 | Time the controller stays in DES before returning to AUT | 00:00 (= disabled) |

### Apoio 1 block (P2)

| Param | Meaning | Factory |
|---|---|---|
| P201 | Mode: 0 independent / 1 tied to Apoio 2 | 0 |
| — | Control hysteresis | 2.0 °C |
| P203 | Max value allowed for the support setpoint | 50.0 °C |
| P204 | Max time (min) for Apoio 1 to reach SPAP before the tied support starts; 0 = disabled | 0 |
| — | Delay after power-up before Apoio 1 control starts | 0 s |

### Apoio 2 block (P3)

| Param | Meaning | Factory |
|---|---|---|
| P301 | Mode: 0 thermostatic heating / 1 barrilete recirculation + heating | 0 |
| — | Control hysteresis | 2.0 °C |
| P303 | Max value allowed for the support setpoint | 50.0 °C |
| P304 | Recirculation scan duration (P301 = 1 only) | 5 min |
| P305 | Recirculation scan interval (P301 = 1 only) | 15 min |

### Sensors block (P4)

- Offsets T1/T2/T3: −10..10 °C (factory 0).
- **P404 T3 attachment**: 0 = T3 disabled / 1 = T3 reservoir / 2 = T3 barrilete
  recirculation (factory 1). Determines which sensor thermostats the supports
  (T2 or T3), and whether AUT2 is available.

## 10. Level-3 programming — time agenda (hold clock key; code 162)

- **5 events**; each has Liga (start) and Desliga (end) times, per-weekday enable toggles
  (all weekdays on by default; factory times 12:00 → 23:59).
- Optional **atrelamento** (tying) of the two supports: when enabled, both supports share the
  same on/off times (factory: NÃO).

## 11. Behaviour — the parts that matter

- **11.1 General**: pump starts when ΔT(T1−T2) ≥ P101, stops when ≤ P102; it cycles
  continuously while the sun is available. The setpoint does not limit this loop.
- **11.2 Anti-freeze**: T1 below P103 runs the pump to bring warm tank water to the collector.
- **11.3 T1 overheat**: T1 above P104 stops the pump until T1 < P104 − 2.0 °C.
- **11.4 SAT2 (T2 comfort)**: T2 above SAT2 stops the pump (comfort/overheat cap on the tank).
- **11.5 AUT1 vs AUT2**: AUT1 = pump purely on T1−T2; AUT2 additionally requires T1 > T3.
- **11.6 Control modes**:
  - `ECO`: only solar heating enabled **plus** boiler cooling; supports fully disabled (no
    schedule, no manual activation). Boiler cooling activates when T1−T2 = −4.0 °C and the
    tank (T3, or T2 when T3 is disabled) is above P106; it runs the pump to shed tank heat
    down to the P106 value.
  - `AUT`: solar controls active; supports activate **via the time agenda or manual
    activation**.
  - `LIG`: both supports manually on simultaneously, max 2 h or until SPAP.
  - `DES`: everything disabled; if P109 is configured, returns to AUT after that time.
- **11.7 / 11.9 Supports as thermostats** (P201 = 0 / P301 = 0): heat while the programmed
  event is active, respecting SPAP (or up to 2 h for a manual activation).
- **11.8 Apoio 1 tied to Apoio 2** (P201 = 1): the second support starts only if Apoio 1 did
  not reach SPAP within P204 minutes — e.g. gas first, electric second.
- **11.10 Apoio 2 recirculation** (P301 = 1): recirculation/heating of the barrilete per the
  agenda or manual activation; scan cycles use P304/P305 while T3 < SPAP.
- **11.11 T3 attachment**: which sensor the support thermostats use (T2 vs T3), and the
  recirculation-without-temperature-control case when T3 is off.

## 12. Error / signal indications

- T1 / T2 / T3 sensor fault (damaged, loose, shorted, out of range).
- Apoio 1 control delayed after power-up; Apoio 1 setpoint not reached within P204.
- T1 overheat (above P104); T1 anti-freeze (below P103).

## 13. Wiring & installation notes

- Connection diagrams: 13.2 solar + gas support + electric support; 13.3 solar + gas support +
  barrilete recirculation; 13.4 solar + electric support + barrilete recirculation.
- Smart Connect accessory: power the controller OFF while installing; connect the accessory to
  the controller; avoid mounting near metal that attenuates Wi-Fi.

## 14–15. Dimensions / sensor placement

Mechanical details and recommended sensor/device positions per the diagram — see the original
manual if needed.
