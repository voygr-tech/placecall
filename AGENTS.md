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
  -d '{"target_phone":"+1XXXXXXXXXX","brief":"<the full task in plain English>","language":"en"}'
# -> 202 {"call_id":"<uuid>","status":"queued"}
```
- `target_phone` E.164 (required); `brief` (required) = the ONLY thing the bot
  reads — put every detail (what to ask, who for, names/dates/party size/callback
  number, how to wrap up). `language`: en|ru|es|auto (`de` unsupported; `en` most
  reliable). Booking/cancel = describe it in the brief.
- Capture the top-level `call_id`.

## Follow the call (poll; don't hold the stream open)
Poll `GET /calls/{id}/events?after_event_id=N` with `--max-time 5`, tracking the
last `id:`. Use the `?after_event_id=` query param, NOT the `Last-Event-ID`
header (the gateway strips it). On `event: ask_user` → answer promptly via
`POST /calls/{id}/answer` `{"request_id","answer"}` (bot waits ~60s). On
`event: outcome` → terminal.

## Get the result — `GET /calls/{id}`
Returns `status`, `outcome_type`, `summary`, `transcript_full`.
**⚠️ Wait ~30s after `status:completed` — the outcome/transcript populate ~20–30s
LATER; reading at the instant of completion gives nulls.** Don't trust
`success_no_booking` blindly — read `transcript_full`.

## Credits & errors
`GET /v1/usage` → remaining (~10 credits/call). `402` = out of credits.
Recording is NOT downloadable via the API (transcript is the record).
Only dial numbers you're authorized to call.
