# callwright — give your agent a phone ☎️

**One API endpoint that places a real phone call for you.** Hand it a number and
a plain-English task; callwright dials it, talks to whoever answers, works through
menus/hold, and returns a structured result + full transcript. It's how your
agent reaches the ~80% of businesses that have a phone, not an API — inquiries,
booking, lead-gen, appointment-setting.

```sh
curl -s -X POST https://api.voygr.tech/calls \
  -H "X-API-Key: $CALLWRIGHT_API_KEY" -H "Content-Type: application/json" \
  -d '{"target_phone":"+1XXXXXXXXXX","brief":"Call this restaurant and ask what time the kitchen closes tonight.","language":"en"}'
```

## Get your key
Ask the organizers for a **callwright API key**, then:
```sh
export CALLWRIGHT_API_KEY="<your key>"
curl -s -H "X-API-Key: $CALLWRIGHT_API_KEY" https://api.voygr.tech/users/me   # sanity check
```
Never commit or paste the key — keep it in the env var.

## Install

### Claude Code
```sh
git clone https://github.com/voygr-tech/callwright-skill && cd callwright-skill
./install.sh          # copies SKILL.md -> ~/.claude/skills/callwright-skill/
```
Set `CALLWRIGHT_API_KEY`, start a **fresh** Claude Code session (skills load at
startup), and ask it to call a number — it uses the skill automatically.

### Codex
Codex reads **`AGENTS.md`**, not `SKILL.md`. Copy this repo's `AGENTS.md` to your
project root (or `~/.codex/AGENTS.md`), set `CALLWRIGHT_API_KEY`, and go.

### Any agent / plain shell
No install needed — the API is just HTTP. `SKILL.md` is the full reference; a
model with a shell tool can place calls straight from it.

## The one rule
**Everything goes in the `brief`** — the bot reads only your brief. Put every
detail in it (what to ask, who you're calling for, names/dates/party size/callback
number, how to wrap up). One endpoint, describe the task, done.

## Good to know
- Each call ≈ **10 credits** (`GET /v1/usage` for your balance; `402` when out).
- After a call `completed`, **wait ~30s** before reading `GET /calls/{id}` — the
  outcome/transcript populate a bit *after* the status flips.
- `en` is most reliable; other languages are best-effort.
- Only call numbers you're authorized to — real calls ring real phones.

**Full reference:** [`SKILL.md`](./SKILL.md) (Claude Code) · [`AGENTS.md`](./AGENTS.md) (Codex).

**Live API docs:** <https://api.voygr.tech/docs> — log in with your callwright key (the same one you set as `CALLWRIGHT_API_KEY`).
