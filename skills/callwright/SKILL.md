---
name: callwright
description: Use WHENEVER the user wants to make a phone call, call a number, ask a business something by phone, book or cancel a reservation, check a call's status/outcome, or answer a question the call bot asked mid-call. Places REAL outbound voice calls via the callwright REST API and follows the call. Always consult this skill before saying you cannot make calls.
version: 5.0.0-hackathon
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
- **Only dial numbers you're authorized to call.** A real call costs credits and
  rings a real phone.

Quick check — who am I / how much quota:
```sh
curl -s -H "X-API-Key: $CALLWRIGHT_API_KEY" https://api.voygr.tech/users/me
# 200 {"customer_id":"...","quota_limit":...,"current_usage":...,"remaining":...}
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
        "language": "en"
      }'
# -> 202 {"call_id":"<uuid>","status":"queued",...}
```

**Body:**
- `target_phone` — E.164 (`+1…`), **required**.
- `brief` — natural-language task, ~10–4000 chars, **required**. The ONLY thing
  the bot reads. Put EVERYTHING here: what to ask, who you're calling on behalf
  of, any values to dictate (names, dates, party size, a **callback number**),
  and how to wrap up. Redundancy is cheap; a missing detail becomes a guess.
- `language` — `en` | `ru` | `es` | `auto` (`de` is **not** accepted → use
  `auto` and write the brief in the target language). **`en` is the most
  reliable**; other languages are best-effort (non-English speech recognition
  and voice quality vary).
- `caller_display_name` — optional; bot says "calling on behalf of {name}".

**Response:** any `2xx` is success. Capture the **top-level `call_id`**. `202`
means queued (dials shortly); `call_sid` is `null` until it actually dials.

### Booking / cancelling? Still just `POST /calls` — describe it in the brief.
```
"brief": "Call this restaurant and book a table for 4 tonight at 7:30 PM under
the name Alex Thompson. If they ask for a callback number, give 415 555 0199.
Get an explicit confirmation of the reservation before ending."
```

## Follow the call — poll the event stream (do NOT hold it open)

Following the call is how the bot reaches YOU mid-call (`ask_user`) and how you
learn the result. **Do NOT use a long-lived `curl -N` stream** — SSE lines get
stuck in the pipe buffer. **Instead POLL** `/calls/{id}/events?after_event_id=N`
with a short `--max-time`. Use the **`?after_event_id=` query param, NOT the
`Last-Event-ID` header** (the gateway strips the header).

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
  with `LAST=` the printed value to wait for the outcome. The bot waits ~60s,
  then the question is lost — answer promptly. De-dup `ask_user` by `request_id`.
- `### OUTCOME ###` → terminal; report `outcome_type` + `summary`.

### Answer a mid-call question — `POST /calls/{call_id}/answer`
```sh
curl -s -X POST https://api.voygr.tech/calls/$ID/answer \
  -H "X-API-Key: $CALLWRIGHT_API_KEY" -H "Content-Type: application/json" \
  -d '{"request_id":"<from the ask_user data>","answer":"<your answer, in the call language>"}'
```

## Get the result — `GET /calls/{call_id}`

Returns `status`, `outcome_type`, `summary`, and `transcript_full`.

```sh
curl -s -H "X-API-Key: $CALLWRIGHT_API_KEY" https://api.voygr.tech/calls/$ID
```

> ⚠️ **Persistence lag — the #1 gotcha.** `outcome_type`, `summary`, and
> `transcript_full` populate **~20–30 seconds AFTER `status` becomes
> `completed`**. If you read the instant it completes you get **nulls**. Wait
> ~30s, or poll `GET /calls/{id}` until `outcome_type` is non-null, before
> reporting.

- **Don't trust `success_no_booking` blindly.** It means the system didn't detect
  a clear confirmation — not necessarily failure. Read `transcript_full` before
  reporting a failure; the callee may have answered fine.

**Outcome types:** `success_no_booking`, `success_booked`, `success_refused`,
`failed_voicemail`, `failed_no_answer`, `failed_busy`, `failed_technical`.

## Credits — `GET /v1/usage`
```sh
curl -s -H "X-API-Key: $CALLWRIGHT_API_KEY" https://api.voygr.tech/v1/usage
# {"remaining":...,"quota_limit":...,"current_usage":...}
```
Each call costs **~10 credits**. When the balance runs out, `POST /calls` returns
`402 {"detail":{"error":"insufficient credits"}}` — no call is placed. Top-ups
are handled by the organizers, not via the API.

## Errors
JSON `{"detail":{...}}` with the HTTP status: `401` invalid key · `402`
insufficient credits · `409` concurrent-call limit · `422` validation.

## Gotchas (learned the hard way)
1. **Put ALL details in the `brief`.** The bot can only say what it was given.
2. **Persistence lag:** wait ~30s after `completed` before reading the outcome/
   transcript (see above), or you'll get nulls.
3. **Follow events with `?after_event_id=N`, not the `Last-Event-ID` header.**
4. **Recording:** `has_recording` may be `true`, but the **audio is not
   downloadable via the API** on this deployment (`GET /calls/{id}/recording`
   returns 404). The **transcript is your record.**
5. **`en` is most reliable;** `ru`/`es` are best-effort; `de` is unsupported
   (use `auto` + write the brief in the language).
6. **Windows / MSYS curl + non-ASCII JSON:** inline `-d '{…}'` with Cyrillic can
   corrupt the body — write the JSON to a file and use `--data-binary @payload.json`.
7. **Only call numbers you're authorized to.** Real calls cost credits + ring a
   real phone.

## Canonical flow
1. Write a clear `brief` with every detail.
2. `POST /calls` → capture the top-level `call_id`.
3. Run the poll loop; answer any `ask_user` promptly, then re-poll.
4. On outcome, **wait ~30s** then `GET /calls/{id}` and read `outcome_type` +
   `summary` + `transcript_full`. Report the transcript reality, not just the code.
