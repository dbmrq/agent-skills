# Smart Connect local socket — protocol reference

The Tholz Smart Connect dongle exposes a small, unauthenticated, plain-TCP JSON protocol on
port **4000** (default; as configured in the app). There is no TLS and no auth. It only
answers while the dongle itself has internet connectivity — the controller keeps running
without it.

One short-lived TCP connection per request works fine. Responses may arrive fragmented:
accumulate bytes until `json.loads` succeeds (a simple read-until-parses loop).

## `getDevice` (read everything)

Request:

```json
{"command":"getDevice"}
```

Real response from a TSZ1392N (SmartHeat 1ª geração, fw P850V3):

```json
{
  "command": "getDevice",
  "response": {
    "id": 21392,
    "reset": 0,
    "error": 0,
    "connected": true,
    "updating": false,
    "firmware": "P850V3",
    "timezone": -10800,
    "heating": {
      "on": false,
      "mode": 3,
      "opMode": 3,
      "unit": true,
      "t1": 535,
      "t2": 454,
      "sp": 450,
      "maxSp": 600
    },
    "outputs": {
      "out0": {"id": 2, "on": false, "onAut": false},
      "out1": {"id": 1, "on": false, "onAut": false}
    }
  }
}
```

Field notes:

| Field | Meaning |
|---|---|
| `id` | Device/model id (21392 = TSZ1392N). |
| `error` | 0 = no error; other values map to the manual's §12 signals. |
| `firmware`, `timezone` | e.g. `P850V3`; timezone in seconds (−10800 = UTC−3). |
| `heating.on` | Solar **circulation pump currently running** (not an enable flag). |
| `heating.mode` | Heating **type** (3 = solar residencial). Not the operation mode. |
| `heating.opMode` | Operation mode: 0 DESLIGADO, 1 LIGADO, 2 AUTOMÁTICO, 3 ECONÔMICO. |
| `heating.t1` / `t2` | Temperatures in tenths of °C (collector / tank). Newer devices may add `t3`; 1ª geração does not. |
| `heating.sp` | SPAP, the **supports'** setpoint, tenths of °C. |
| `heating.maxSp` | Max allowed SPAP, tenths of °C (`minSp` may be absent on legacy devices). |
| `outputs.outN.id` | Output type: 1 = electric support (apoio elétrico), 2 = gas support (apoio a gás). |
| `outputs.outN.on` | Relay/manual state as reported by the controller. |
| `outputs.outN.onAut` | Second state flag; exact meaning undocumented — likely the automatic/scheduled activation state. |

Other Tholz products expose different sub-blocks (e.g. `leds`, `monitors`); round-trip any
unknown fields unchanged when writing.

## `setDevice` (write)

Writes are **whole sub-block snapshots**, not field patches: send the complete block as read,
with your changes applied:

```json
{"command":"setDevice","argument":{"heating":{"on":false,"mode":3,"opMode":2,"unit":true,"t1":535,"t2":454,"sp":550,"maxSp":600}}}
```

Outputs are their own sub-block:

```json
{"command":"setDevice","argument":{"outputs":{"out1":{"id":1,"on":true,"onAut":false}}}}
```

The response echoes the resulting state.

## Nuances learned the hard way

- A write is **accepted** even when the physical effect cannot happen (e.g. the support relay
  has no load). Never trust `on`/`onAut` as proof of heating — verify with the tank temperature
  (0.1 °C) or the controller LCD indicator.
- Modes can change themselves: LIGADO can revert to AUTOMÁTICO by itself once SPAP is reached
  (observed within seconds of being set when the tank was already at the setpoint). To start
  LIG over the socket: write the higher SPAP **first**, then `opMode 1`.
- Every support activation path observed so far (manual `outputs.*.on` write, LIG) engaged
  **both** outputs together — don't rely on per-support granularity for these.
- With no active agenda event, AUTOMÁTICO does nothing visible; the agenda itself is not
  exposed over the socket.
- `heating.on` toggles with the pump's differential cycling — do not read it as a mode setting.
- The dongle's **local TCP server can hang** while the dongle stays cloud-connected (the phone
  app keeps working and the host still answers pings). Kicking its Wi-Fi association (from the
  AP/controller) or power-cycling restores local control; Home Assistant goes `unavailable`
  meanwhile.
