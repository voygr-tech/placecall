# Installing PlaceCall (for AI agents such as Cline)

PlaceCall is a hosted remote MCP server. There is nothing to clone, build or
run locally. Your agent connects to `https://api.voygr.tech/mcp` over
Streamable HTTP. It can then place real outbound phone calls to US
businesses and read back the outcome and transcript.

## 1. Get an API key
The user gets a key at <https://api.voygr.tech/checkout>, and it arrives by email.
Ask the user to paste it. Never invent one. Keep the key out of chat logs and
commits.

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
`get_call_result` and `answer_question`. `suggest_places` places no call, but
it is billed too: each answered request costs 5 credits. Do not run
`place_call` as a test, because every invocation dials a real phone and is
billed.

Keep `autoApprove` empty for `place_call`, so the user confirms each call.

## Notes
- US numbers only.
- Calls are recorded, and recordings and transcripts are kept for 90 days.
- Docs: <https://api.voygr.tech/docs>. Network details: [README, Network access](./README.md#network-access).
