---
name: callwright
description: Use WHENEVER the user wants to make a phone call, call a number, ask a business something by phone, book or cancel a reservation, check a call's status/outcome, or answer a question the call bot asked mid-call. Places REAL outbound voice calls via the callwright REST API and follows the call. Always consult this skill before saying you cannot make calls.
version: 5.2.1
author: voygr-tech
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [phone, calls, voice, telephony, api, sse, events, booking]
    related_skills: []
---

# callwright — place real phone calls via one REST API

You CAN place real phone calls. You do NOT need a native voice/telephony tool —
you make calls by sending HTTP requests to the callwright API with your
shell/terminal tool (`curl`). NEVER tell the user you cannot make calls or that
you lack a voice function. When the user asks to call, ask, book, or cancel by
phone — DO IT via this API.

The backend dials the number, talks to whoever answers (in the chosen language),
performs the task described in your `brief`, and reports an outcome + transcript.
**There is one endpoint you need — `POST /calls` — and everything goes in the
`brief`.**

## Connection

- **Base URL:** `https://api.voygr.tech` (HTTPS).
- **Auth:** EVERY request sends the header `X-API-Key`, value = **your callwright
  key**. Store it in the env var `CALLWRIGHT_API_KEY`; NEVER print or echo the
  value — reference it as `$CALLWRIGHT_API_KEY` in shell commands.
- **No key yet? Self-serve, no human in the loop:** open
  <https://api.voygr.tech/checkout> and use **"Get free API key"** (name +
  email), or `POST /signup` with `{"name":"...","email":"..."}` — the key is
  **emailed** to you, never returned in the response. The free tier comes with
  2,500 credits (enough for 250 successful calls) and a 25-calls/day cap;
  any credit purchase lifts the cap to 5,000/day (credits become the only
  practical limit). Lost your key? <https://api.voygr.tech/recover> emails
  you a fresh one.
- **Rules:** only dial numbers you're authorized to call — a real call costs
  credits and rings a real phone. US destinations only. Every call announces
  it's an AI assistant and that it's recorded (non-configurable).

Quick check — who am I / how much quota:
```sh
curl -s -H "X-API-Key: $CALLWRIGHT_API_KEY" https://api.voygr.tech/users/me
# 200 {"customer_id":"...","quota_limit":...,"current_usage":...,
#      "credits_available":...,"credits_held":...,"max_concurrent_calls":...}
```

## Place a call — `POST /calls` (this is the whole product)

Give a phone number and a **plain-English `brief`** of the task. One call covers
everything — an inquiry, a booking, a cancellation, a follow-up — by describing
it in the brief. The bot reads **only** the `brief`, so put every detail in it.

```sh
curl -s -X POST https://api.voygr.tech/calls \
  -H "X-API-Key: $CALLWRIGHT_API_KEY" -H "Content-Type: application/json" \
  -d '{
        "target_phone": "+15551234567",
        "brief": "Call this sports bar and find out (1) whether they are showing the USA vs Netherlands match today and (2) whether a reservation is needed. Read the answers back to confirm, thank them, and end.",
        "language": "en",
        "ask_user_mode": "stream"
      }'
# -> 201 {"call":{"call_id":"...","status":"dialing",...},"credits_reserved":30,...}
```

**Body:**
- `target_phone` — E.164 (`+1…`), **required on this freeform path**. `911` and
  other N11 service codes are refused for every account (`422`).
- `brief` — natural-language task, max 4000 chars, **required on this freeform
  path**. The ONLY thing the bot reads. Put EVERYTHING here: what to ask, who
  you're calling on behalf of (there is NO separate caller-name field — put the
  name in the brief), any values to dictate (names, dates, party size, a
  **callback number**), and how to wrap up. Redundancy is cheap; a missing
  detail becomes a guess.
- `language` — ISO 639-1 code or `auto` (the default, resolves to `en`). 13
  accepted: `en`, `es`, `fr`, `de`, `hi`, `ru`, `pt`, `ja`, `it`, `nl`, `sr`,
  `tr`, `pl`. Anything else → `422 unsupported_language` with the full list in
  the hint. **`en` is the most battle-tested** — non-English is accepted but
  best-effort (and the platform currently dials US numbers only).
- `ask_user_mode` — **always send `"stream"`**. It routes the bot's mid-call
  `ask_user` questions ONLY to the `GET /calls/{id}/events` feed you poll
  below. With the default (`"any"`) the question may be routed to other
  channels (webhook, operator) and your poll loop may never see it.

**Response:** `201 Created` — the call object is wrapped in an envelope; the id
you need is **`call.call_id`** (on deployments that queue calls you may see
`202` with `status: "queued"` instead — same poll loop either way). `call_sid`
is `null` until it actually dials. `credits_reserved` (30) is a refundable
hold, not a charge — the actual charge on success is 10.

### Booking / cancelling? Still just `POST /calls` — describe it in the brief.
```
"brief": "Call this restaurant and book a table for 4 tonight at 7:30 PM under
the name Alex Thompson. If they ask for a callback number, give 415 555 0199.
Get an explicit confirmation of the reservation before ending."
```

### Prefer typed inputs? The structured path (optional, same endpoint)

Instead of writing a `brief`, send `intent` + `slots` and the server builds the
brief deterministically. Five intents:

| Intent | Required slots |
|---|---|
| `inquiry` | `target_phone`, `question` |
| `info_gathering` | `target_phone`, `questions` |
| `issue_resolution` | `target_phone`, `issue_description` |
| `booking` | `target_phone`, `name`, `date` (`YYYY-MM-DD`), `time` (`HH:MM`), `party_size` |
| `cancellation` | `booking_id` of an ACTIVE booking made through this API — no phone slot |

```sh
curl -s -X POST https://api.voygr.tech/calls \
  -H "X-API-Key: $CALLWRIGHT_API_KEY" -H "Content-Type: application/json" \
  -d '{"target_phone": "+15551234567", "intent": "info_gathering",
       "language": "en", "ask_user_mode": "stream",
       "slots": {"target_phone": "+15551234567",
                 "questions": "whether they show the USA match today, and whether a reservation is needed"}}'
```

- Missing/invalid slots → **422 with `error_code: "missing_slots"`** listing each
  gap with a ready-made `suggested_question` — ask your user, refill, resubmit.
  That loop is the whole point of this path. Nothing is charged or dialed until
  the slots are complete. Schema discovery: `GET /skills/{skill_id}/manifest`
  (e.g. `concierge`). An unknown intent → `422 unknown_intent` with the list.
- The 2xx envelope on this path is **flat** — a top-level `call_id` (no `call`
  wrapper), plus `status_url` / `answer_url` — follow/poll it exactly like a
  freeform call.
- **For bookings, prefer this structured path.** Its slots are checked before
  anything is dialed, so a detail you left out comes back as a `422` you can
  still fix; on the freeform path the `brief` is taken verbatim and the same gap
  surfaces mid-call, as a question the bot has to improvise. For inquiries
  either path is fine — pick whichever fits your agent.
- **Always give the bot a callback number for a booking.** "What number can we
  reach you at?" is the question staff ask most often, and a call that cannot
  answer it tends to end without a confirmed reservation. On `booking` send the
  optional `phone_to_dictate` slot (the bot reads it back digit by digit); on
  the freeform path put the number in the `brief`.
- Don't mix both in one request — send either a `brief` or `intent` + `slots`.

## Follow the call — poll the event stream (do NOT hold it open)

Following the call is how the bot reaches YOU mid-call (`ask_user`) and how you
learn the result. **Do NOT use a long-lived `curl -N` stream** — SSE lines get
stuck in the pipe buffer. **Instead POLL** `/calls/{id}/events?after_event_id=N`
with a short `--max-time`. Use the **`?after_event_id=` query param, NOT the
`Last-Event-ID` header** (the query param wins and survives proxies that strip
the header).

```sh
ID=<call_id>; LAST=0; STOP=$(($(date +%s)+120))
while [ "$(date +%s)" -lt "$STOP" ]; do
  OUT=$(curl -s --max-time 5 -H "X-API-Key: $CALLWRIGHT_API_KEY" \
        "https://api.voygr.tech/calls/$ID/events?after_event_id=$LAST")
  [ -n "$OUT" ] && echo "$OUT"
  N=$(printf '%s' "$OUT" | sed -n 's/^id: //p' | tail -1); [ -n "$N" ] && LAST=$N
  printf '%s' "$OUT" | grep -q '^event: outcome'  && { echo "### OUTCOME — done ###"; break; }
  printf '%s' "$OUT" | grep -q '^event: ask_user' && { echo "### ASK_USER — answer now ###"; break; }
  sleep 1
done
```
- `### ASK_USER ###` → read `request_id` + `message` from the `data:` JSON, get
  the answer (ask the human if needed), POST it (below), then re-run the loop
  with `LAST=` the printed value to wait for the outcome. The bot waits a
  bounded window (~60s), then proceeds without you — answer promptly. The
  backfill can repeat events, so **de-dup `ask_user` by `request_id`**.
- `### OUTCOME ###` → terminal; report `outcome_type` + `summary`.
- Other event types you may see: `status_change`, `recording_ready`,
  `transcript_ready`. `503 too_many_sse_streams` → back off per `Retry-After`.

### Answer a mid-call question — `POST /calls/{call_id}/answer`
```sh
curl -s -X POST https://api.voygr.tech/calls/$ID/answer \
  -H "X-API-Key: $CALLWRIGHT_API_KEY" -H "Content-Type: application/json" \
  -d '{"request_id":"<from the ask_user data>","answer":"<your answer, in the call language>"}'
```
`200 {"delivered": true}`. `delivered: false` with `reason: "no_pending_request"`
means the question timed out or the call ended — the bot never heard you; do
not treat it as success.

## Get the result — `GET /calls/{call_id}`

Returns `status`, `outcome_type`, `outcome_summary`, and `transcript_full`.

```sh
curl -s -H "X-API-Key: $CALLWRIGHT_API_KEY" https://api.voygr.tech/calls/$ID
```

> ⚠️ **Don't stop at the status flip.** If `status` just became `completed` but
> `outcome_type` / `transcript_full` are still `null`, the result hasn't
> finished persisting — keep polling `GET /calls/{id}` every few seconds until
> `outcome_type` is non-null before reporting.

- **Always read `transcript_full`, not just the code.** `success_no_booking` is a
  billable success — information was obtained without a booking; the details
  live in the transcript, so report from it. (`transcript_full` rows carry a
  `role` — filter out `system` markers; a cleaner post-call merged transcript
  is at `GET /calls/{id}/transcript-merged`, `202 merger_pending` until ready.)
- **Recording:** when `has_recording` is `true`, `recording_url` is a
  **relative** path (`/calls/{id}/recording`) — prepend the base URL and fetch
  with the same `X-API-Key` to download the audio.

**Outcome types (all of them — your agent WILL meet every one):**
- `success_booked` / `success_refused` / `success_no_booking` — a real
  conversation happened (booked / venue said no / info obtained). Billed.
- `failed_short_hangup` — **the most common failure**: someone picked up but
  hung up before a real conversation (often right after the AI disclosure). Free.
- `failed_voicemail`, `failed_no_answer`, `failed_busy` — nobody reached. Free.
- `failed_no_agent_available` — a hold queue played music past the hold budget
  and no human ever picked up. Free.
- `failed_no_disclosure` — the mandatory recording/AI notice couldn't be
  delivered (or the callee hung up during it), so the call ended early. Free.
- `failed_technical` — carrier/system error, incl. reaching a wrong business. Free.

## Other endpoints

- `GET /calls?limit=20` — list your calls, most recent first (no transcripts).
- `POST /calls/{id}/cancel` — cancel a not-yet-terminal call, releases the
  hold. Idempotent: `{"cancelled": false}` for unknown/terminal calls, never 404.
- `PUT /users/me/limits` — raise your own `max_concurrent_calls` up to the
  key's admin ceiling (`max_concurrent_calls_ceiling` on `GET /users/me`).

## Credits & top-ups

```sh
curl -s -H "X-API-Key: $CALLWRIGHT_API_KEY" https://api.voygr.tech/v1/usage
# {"remaining":...,"quota_limit":...,"current_usage":...,"tier":...}
```
**Only successful calls are billed** — a `success_*` outcome costs **10
credits**; every `failed_*` outcome costs **0**. Voicemails, hangups, and busy
lines don't burn your quota. Each call takes a refundable **30-credit hold**
(3× the charge) at dial time; on settlement the hold becomes the 10-credit
charge (success) or is fully refunded (failure). So `POST /calls` returns
`402 insufficient credits` whenever your available balance is under **30** —
even though a call only *costs* 10. Keep ≥30 headroom per concurrent call.

**Top-ups are self-serve:** <https://api.voygr.tech/checkout> (Stripe-hosted
payment; credit packs listed at `GET /checkout/packs`). The 402 body also
carries a `checkout_url`.

## Errors
JSON `{"detail":{...}}` with the HTTP status: `401` invalid key · `402`
insufficient credits · `403` tier/entitlement not permitted · `409`
concurrent-call limit (body lists `active_call_ids` — cancel one or wait) ·
`422` validation (see `error_code` inside `detail`) · `429` rate limit (10
req/s, 100 req/min) **or** daily call ceiling reached (distinguish by
`detail.error`; the ceiling counts calls *created* per UTC day — 25/day on the
free tier, 5,000/day once you've purchased credits — and resets at UTC
midnight, see `resets_at`) · `503` maintenance
window or transient refusal — retry later.

## Gotchas (learned the hard way)
1. **Put ALL details in the `brief`.** The bot can only say what it was given.
2. **The freeform `call_id` is nested** — `201` returns `{"call": {"call_id":
   ...}}`; the structured path returns it top-level. Extract accordingly.
3. **Poll until `outcome_type` is non-null** — a just-completed call can still
   show `null` outcome/transcript for a few seconds (see above).
4. **Follow events with `?after_event_id=N`, not the `Last-Event-ID` header.**
5. **Language codes are validated** — 13 accepted + `auto` (the default);
   anything else is a fast `422`, nothing is dialed or charged. `en` is the
   most reliable; non-English is best-effort.
6. **The hold (30) is bigger than the charge (10)** — a balance of 10-29 can't
   fund a call even though a call only costs 10. Keep ≥30 available.
7. **Windows / MSYS curl + non-ASCII JSON:** inline `-d '{…}'` with Cyrillic can
   corrupt the body — write the JSON to a file and use `--data-binary @payload.json`.
8. **Only call numbers you're authorized to.** Real calls cost credits + ring a
   real phone. US destinations only.
9. **Always create calls with `ask_user_mode: "stream"`** — without it, mid-call
   `ask_user` questions may be routed to other channels and never reach your
   events poll loop.

## Canonical flow
1. Write a clear `brief` with every detail.
2. `POST /calls` → capture the `call_id` (`call.call_id` on the freeform path).
3. Run the poll loop; answer any `ask_user` promptly, then re-poll.
4. On outcome, poll `GET /calls/{id}` until `outcome_type` is non-null, then
   read `outcome_type` + `outcome_summary` + `transcript_full`. Report the
   transcript reality, not just the code.
