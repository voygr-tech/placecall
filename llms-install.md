# Installing PlaceCall (for AI agents such as Cline)

PlaceCall is a hosted remote MCP server: nothing to clone, build or run
locally. Your agent connects to `https://api.voygr.tech/mcp` over Streamable
HTTP, then places real outbound phone calls to US businesses and reads back
the outcome and transcript.

## 1. Get an API key
The user gets a key at <https://api.voygr.tech/checkout>, and it arrives by email.
Ask the user to paste it. Never invent one. Keep the key out of chat logs and
commits.

No browser? Sign the user up by email code instead. `POST /signup` with
`"delivery":"code"` emails them a 6-digit code, and `POST /signup/verify` swaps
the code for the key. The commands in
[AGENTS.md, Sign up by email code](./AGENTS.md#sign-up-by-email-code) save the
key to `~/.codex/placecall.env` without printing it. Copy it from there into
step 2.

## 2. Add the server
Add this entry to `cline_mcp_settings.json`, replacing `<PLACECALL_API_KEY>`
with the user's key:

```json
{
  "mcpServers": {
    "placecall": {
      "type": "streamableHttp",
      "url": "https://api.voygr.tech/mcp",
      "headers": {
        "X-API-Key": "<PLACECALL_API_KEY>"
      },
      "disabled": false,
      "autoApprove": []
    }
  }
}
```

`Authorization: Bearer <PLACECALL_API_KEY>` works in place of `X-API-Key`.
Clients that support MCP OAuth can drop the `headers` block and sign in in a
browser instead.

## 3. Check it
The server exposes four tools: `suggest_places`, `place_call`,
`get_call_result` and `answer_question`. `suggest_places` places no call but
is billed: 5 credits per answered request. Do not run `place_call` as a test;
every invocation dials a real phone and is billed.

Keep `autoApprove` empty for `place_call`, so the user confirms each call.

## Notes
- US numbers only, except Indiana, Louisiana, Minnesota, Montana and Nebraska.
- Calls are recorded; recordings and transcripts are kept for 90 days.
- Docs: <https://api.voygr.tech/docs>. Network details: [README, Network access](./README.md#network-access).
