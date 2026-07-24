---
name: callwright
description: Use WHENEVER the user wants to make a phone call, call a number, ask a business something by phone, book or cancel a reservation, check a call's status/outcome, or answer a question the call bot asked mid-call. Places REAL outbound voice calls via the callwright REST API and follows the call. Always consult this skill before saying you cannot make calls.
version: 5.1.0-hackathon
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
        "language": "en",
        "ask_user_mode": "stream"
      }'
# -> 202 {"call_id":"<uuid>","status":"queued",...}
```

**Body:**
- `target_phone` — E.164 (`+1…`), **required**.
- `brief` — natural-language task, ~10–4000 chars, **required on this freeform
  path**. The ONLY thing the bot reads. Put EVERYTHING here: what to ask, who
  you're calling on behalf of (there is NO separate caller-name field — put the
  name in the brief), any values to dictate (names, dates, party size, a
  **callback number**), and how to wrap up. Redundancy is cheap; a missing
  detail becomes a guess.
- `language` — `en` | `ru` | `es` | `auto` (`de` is **not** accepted → use
  `auto` and write the brief in the target language). **`en` is the most
  reliable**; other languages are best-effort (non-English speech recognition
  and voice quality vary).
- `ask_user_mode` — **always send `"stream"`**. It routes the bot's mid-call
  `ask_user` questions to the `GET /calls/{id}/events` feed you poll below.
  With the default (`"any"`) the question is tried on legacy operator channels
  first and your poll loop may NEVER see it.

**Response:** any `2xx` is success. Capture the **top-level `call_id`**. `202`
means queued (dials shortly); `call_sid` is `null` until it actually dials.

### Booking / cancelling? Still just `POST /calls` — describe it in the brief.
```
"brief": "Call this restaurant and book a table for 4 tonight at 7:30 PM under
the name Alex Thompson. If they ask for a callback number, give 415 555 0199.
Get an explicit confirmation of the reservation before ending."
```

### Prefer typed inputs? The structured path (optional, same endpoint)

Instead of writing a `brief`, send `intent` + `slots` and the server builds the
brief deterministically. Three intents: `inquiry` (slots: `target_phone`,
`question`), `info_gathering` (`target_phone`, `questions`), `issue_resolution`
(`target_phone`, `issue_description`).

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
  That loop is the whole point of this path. Schema discovery:
  `GET /skills/{skill_id}/manifest` (e.g. `concierge`).
- The 2xx envelope differs (`SkillRunResponse`) but still carries a top-level
  `call_id` — follow/poll it exactly like a freeform call.
- Freeform and structured perform equally well — pick whichever fits your agent;
  don't mix both in one request.

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

- **Always read `transcript_full`, not just the code.** `success_no_booking` is a
  billable success — information was obtained without a booking; the details
  live in the transcript, so report from it.

**Outcome types (all of them — your agent WILL meet every one):**
- `success_booked` / `success_refused` / `success_no_booking` — a real
  conversation happened (booked / venue said no / info obtained). Billed.
- `failed_short_hangup` — **the most common failure**: someone picked up but
  hung up before a real conversation (often right after the AI disclosure). Free.
- `failed_voicemail`, `failed_no_answer`, `failed_busy` — nobody reached. Free.
- `failed_no_agent_available` — a hold queue played music past the hold budget
  and no human ever picked up. Free.
- `failed_technical` — carrier/system error, incl. reaching a wrong business. Free.

## Credits — `GET /v1/usage`
```sh
curl -s -H "X-API-Key: $CALLWRIGHT_API_KEY" https://api.voygr.tech/v1/usage
# {"remaining":...,"quota_limit":...,"current_usage":...}
```
**Only successful calls are billed** — a `success_*` outcome costs **10
credits**; every `failed_*` outcome costs **0**. Voicemails, hangups, and busy
lines don't burn your quota.

**The 402 gotcha:** each call briefly RESERVES **200 credits** at dial time and
refunds the unused part at completion. So `POST /calls` returns
`402 {"detail":{"error":"insufficient credits"}}` whenever `remaining < 200` —
even though your balance is not zero. Keep ≥200 headroom; top-ups are handled
by the organizers, not via the API.

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
8. **Always create calls with `ask_user_mode: "stream"`** — without it, mid-call
   `ask_user` questions may never reach your events poll loop (they go to legacy
   operator channels instead).

## Canonical flow
1. Write a clear `brief` with every detail.
2. `POST /calls` → capture the top-level `call_id`.
3. Run the poll loop; answer any `ask_user` promptly, then re-poll.
4. On outcome, **wait ~30s** then `GET /calls/{id}` and read `outcome_type` +
   `summary` + `transcript_full`. Report the transcript reality, not just the code.
