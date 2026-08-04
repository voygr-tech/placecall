# callwright — place real phone calls (agent instructions)

You can place REAL outbound phone calls by sending HTTP requests to the
callwright API with `curl`. There is no native voice tool — use the API. When
asked to call / ask a business / book / cancel by phone, DO IT via these calls.
(This is the same reference as `SKILL.md`, for Codex/AGENTS.md-based agents.)

## Connection
- Base: `https://api.voygr.tech`
- Auth: header `X-API-Key: $CALLWRIGHT_API_KEY` on EVERY request. Never echo the key.
- No key? Self-serve at <https://api.voygr.tech/checkout> ("Get free API key" —
  emailed, free tier: 2,500 credits, 25 calls/day). Recovery: `/recover`.
- Check: `curl -s -H "X-API-Key: $CALLWRIGHT_API_KEY" https://api.voygr.tech/users/me`

## Place a call — one endpoint, everything in the brief
```sh
curl -s -X POST https://api.voygr.tech/calls \
  -H "X-API-Key: $CALLWRIGHT_API_KEY" -H "Content-Type: application/json" \
  -d '{"target_phone":"+1XXXXXXXXXX","brief":"<the full task in plain English>","language":"en","ask_user_mode":"stream"}'
# -> 201 {"call":{"call_id":"...","status":"dialing",...},"credits_reserved":10,...}
```
- `target_phone` E.164 (required); `brief` (required, max 4000 chars) = the ONLY
  thing the bot reads — put every detail (what to ask, who for — there is no
  separate caller-name field — names/dates/party size/callback number, how to
  wrap up). `language`: 13 codes (en/es/fr/de/hi/ru/pt/ja/it/nl/sr/tr/pl) or
  `auto` (default); anything else is a fast 422. Booking/cancel = describe it
  in the brief.
- **Always send `"ask_user_mode":"stream"`** — otherwise mid-call `ask_user`
  questions may be routed elsewhere and never reach your events poll loop.
- Capture the call id: **nested at `call.call_id`** on this freeform path.
- Typed alternative (same endpoint): send `intent` + `slots` instead of `brief`.
  Five intents: `inquiry`/`info_gathering`/`issue_resolution`/`booking`
  (name, date, time, party_size)/`cancellation` (`booking_id`, no phone). A 422
  `missing_slots` lists each gap with a `suggested_question` — refill and
  resubmit. This path returns a FLAT envelope (top-level `call_id`). Schema:
  `GET /skills/{id}/manifest`.

## Follow the call (poll; don't hold the stream open)
Poll `GET /calls/{id}/events?after_event_id=N` with `--max-time 5`, tracking the
last `id:`. Use the `?after_event_id=` query param, NOT the `Last-Event-ID`
header (the param wins and survives proxies that strip the header). On
`event: ask_user` → answer promptly via `POST /calls/{id}/answer`
`{"request_id","answer"}` (the bot waits a bounded window, then proceeds
without you; de-dup by `request_id` — the backfill can repeat). On
`event: outcome` → terminal.

## Get the result — `GET /calls/{id}`
Returns `status`, `outcome_type`, `outcome_summary`, `transcript_full`.
**⚠️ If `status` is terminal but `outcome_type`/`transcript_full` are `null`,
keep polling every few seconds until `outcome_type` is non-null — the result
persists just after the status flips.** Always report from `transcript_full`
(`success_no_booking` = billable success: info obtained, no booking). Outcomes:
`success_booked|success_refused|success_no_booking` (billed, 10 credits) ·
`failed_short_hangup` (most common failure — picked up, hung up early) ·
`failed_voicemail|failed_no_answer|failed_busy|failed_no_agent_available|failed_no_disclosure|failed_technical` (all free).
Recording: when `has_recording` is true, GET `recording_url` (relative path)
with your API key to download the audio. Merged post-call transcript:
`GET /calls/{id}/transcript-merged`. Cancel a call: `POST /calls/{id}/cancel`.

## Credits & errors
`GET /v1/usage` → remaining (or `GET /users/me` → `credits_available`).
**Only `success_*` outcomes are billed (10 credits); every `failed_*` is 0.**
Each call takes a refundable 10-credit hold at dial time (hold = charge), so
`402` fires when available < 10. Top-ups are self-serve at
<https://api.voygr.tech/checkout> (Stripe). Other errors: `403`
tier/entitlement · `409` concurrency cap (cancel an `active_call_id` or wait;
raise via `PUT /users/me/limits`) · `429` rate limit (10 r/s, 100 r/min) or
daily call ceiling (calls created per UTC day) · `503` maintenance/transient.
Only dial numbers you're authorized to call. US destinations only; every call
discloses it's a recorded AI call.
