# callwright — place real phone calls (agent instructions)

You can place REAL outbound phone calls by sending HTTP requests to the
callwright API with `curl`. There is no native voice tool — use the API. When
asked to call / ask a business / book / cancel by phone, DO IT via these calls.
(This is the same reference as `SKILL.md`, for Codex/AGENTS.md-based agents.)

## Connection
- Base: `https://api.voygr.tech`
- Auth: header `X-API-Key: $CALLWRIGHT_API_KEY` on EVERY request. Never echo the key.
- Check: `curl -s -H "X-API-Key: $CALLWRIGHT_API_KEY" https://api.voygr.tech/users/me`

## Place a call — one endpoint, everything in the brief
```sh
curl -s -X POST https://api.voygr.tech/calls \
  -H "X-API-Key: $CALLWRIGHT_API_KEY" -H "Content-Type: application/json" \
  -d '{"target_phone":"+1XXXXXXXXXX","brief":"<the full task in plain English>","language":"en","ask_user_mode":"stream"}'
# -> 202 {"call_id":"<uuid>","status":"queued"}
```
- `target_phone` E.164 (required); `brief` (required) = the ONLY thing the bot
  reads — put every detail (what to ask, who for — there is no separate
  caller-name field — names/dates/party size/callback number, how to wrap up).
  `language`: en|ru|es|auto (`de` unsupported; `en` most reliable).
  Booking/cancel = describe it in the brief.
- **Always send `"ask_user_mode":"stream"`** — otherwise mid-call `ask_user`
  questions may never reach your events poll loop.
- Capture the top-level `call_id`.
- Typed alternative (same endpoint): send `intent` (`inquiry`/`info_gathering`/
  `issue_resolution`) + `slots` instead of `brief`; a 422 `missing_slots` lists
  each gap with a `suggested_question` — refill and resubmit. Schema:
  `GET /skills/{id}/manifest`.

## Follow the call (poll; don't hold the stream open)
Poll `GET /calls/{id}/events?after_event_id=N` with `--max-time 5`, tracking the
last `id:`. Use the `?after_event_id=` query param, NOT the `Last-Event-ID`
header (the gateway strips it). On `event: ask_user` → answer promptly via
`POST /calls/{id}/answer` `{"request_id","answer"}` (bot waits ~60s). On
`event: outcome` → terminal.

## Get the result — `GET /calls/{id}`
Returns `status`, `outcome_type`, `summary`, `transcript_full`.
**⚠️ Wait ~30s after `status:completed` — the outcome/transcript populate ~20–30s
LATER; reading at the instant of completion gives nulls.** Always report from
`transcript_full` (`success_no_booking` = billable success: info obtained, no
booking). Outcomes: `success_booked|success_refused|success_no_booking` (billed)
· `failed_short_hangup` (most common failure — picked up, hung up early) ·
`failed_voicemail|failed_no_answer|failed_busy|failed_no_agent_available|failed_technical` (all free).

## Credits & errors
`GET /v1/usage` → remaining. **Only `success_*` outcomes are billed (10
credits); every `failed_*` is 0.** Each call reserves 200 credits at dial time
(refunded on completion) → `402` fires whenever `remaining < 200`, even with a
non-zero balance — keep ≥200 headroom.
Recording is NOT downloadable via the API (transcript is the record).
Only dial numbers you're authorized to call.
