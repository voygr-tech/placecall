# callwright — give your agent a phone ☎️

**One API endpoint that places a real phone call for you.** Hand it a number and a
plain-English task; callwright dials it, talks to whoever answers, works through
menus/hold, and returns a structured result + full transcript. It's how your agent
reaches the ~80% of businesses that have a phone, not an API — inquiries, booking,
lead-gen, appointment-setting.

```sh
curl -s -X POST https://api.voygr.tech/calls \
  -H "X-API-Key: $CALLWRIGHT_API_KEY" -H "Content-Type: application/json" \
  -d '{"target_phone":"+1XXXXXXXXXX","brief":"Call this restaurant and ask what time the kitchen closes tonight.","language":"en"}'
```

## Install
Installing the skill needs **no key** — it just teaches your agent how to call the
API. You add your key separately (next section) before placing real calls.

### Claude Code
```sh
git clone https://github.com/voygr-tech/callwright-skill && cd callwright-skill
./install.sh     # copies skills/callwright/SKILL.md -> ~/.claude/skills/callwright/
```
`install.sh` is a tiny convenience script — it **only** copies
`skills/callwright/SKILL.md` into your skills dir (no network, no other side
effects); you can also copy it by hand. Then start a **fresh** Claude Code session
(skills load at startup).

### Codex
Use the Codex skill installer, pointing at the skill subdirectory (the name
`callwright` is inferred from the path):
```sh
python3 install-skill-from-github.py \
  --repo voygr-tech/callwright-skill \
  --path skills/callwright
#   (equivalently, add:  --name callwright)
```
Codex prefers its installer over running third-party scripts, so **don't** run
`install.sh` on Codex — use the command above. (Alternatively, paste this repo's
[`AGENTS.md`](./AGENTS.md) into your project's `AGENTS.md`.)

### Any agent / plain shell
No install needed — the API is just HTTP. `skills/callwright/SKILL.md` is the full
reference; a model with a shell tool can place calls straight from it.

## Get a key (self-serve) and set it
Installing the skill does **not** need a key; **placing calls does.** Keys are
**self-serve** — no need to contact anyone:

1. Open <https://api.voygr.tech/checkout> and click **"Get free API key"**
   (name + email), or `curl -s -X POST https://api.voygr.tech/signup -H
   "Content-Type: application/json" -d '{"name":"<you>","email":"<you@example.com>"}'`.
2. The key arrives **by email** (it is never shown in the browser or API
   response). Free tier: **2,500 credits** (250 successful calls) with a
   25-calls/day cap.
3. Lost the key? <https://api.voygr.tech/recover> emails you a new one.
4. Need more credits? Top up on the same <https://api.voygr.tech/checkout>
   page (Stripe-hosted payment).

Then set the key in your shell:

**Quick way** — just export it for the current session:
```sh
export CALLWRIGHT_API_KEY="<your key>"
```

**Nicer way** — save it once (no echo to screen, `600` perms) and load it per session:
```sh
mkdir -p ~/.codex
read -rsp "CALLWRIGHT_API_KEY: " KEY; echo
printf 'export CALLWRIGHT_API_KEY=%q\n' "$KEY" > ~/.codex/callwright.env
chmod 600 ~/.codex/callwright.env
unset KEY
# then, in any new shell where you want to place calls:
source ~/.codex/callwright.env
```

**Verify** (prints your quota, never the key):
```sh
curl -s -H "X-API-Key: $CALLWRIGHT_API_KEY" https://api.voygr.tech/users/me
```
Never commit `~/.codex/callwright.env` or paste the key into chat — keep it in the
env var / the `600` file above.

## Replacing an older phone skill?
If you previously installed another phone-call skill (e.g. `ai-call-agent`),
**remove or disable it** so your agent doesn't get ambiguous routing between two
calling skills.

## The one rule
**Everything goes in the `brief`** — the bot reads only your brief. Put every detail
in it (what to ask, who you're calling for, names/dates/party size/callback number,
how to wrap up). One endpoint, describe the task, done.

## Good to know
- **Only successful calls are billed** (10 credits per `success_*` outcome;
  voicemails/hangups/no-answers are free). Each call takes a refundable
  **30-credit hold** at dial time (3× the charge, settled down to 10 on
  success) — under 30 available and `POST /calls` returns `402` even with a
  non-zero balance (`GET /users/me` for your balance; top-ups are self-serve
  at <https://api.voygr.tech/checkout>).
- After a call `completed`, the outcome/transcript can populate a moment
  *after* the status flips — poll `GET /calls/{id}` until `outcome_type` is
  non-null.
- 13 language codes accepted (`en`, `es`, `fr`, `de`, `hi`, `ru`, `pt`, `ja`,
  `it`, `nl`, `sr`, `tr`, `pl`) plus `auto` (the default, resolves to `en`).
  `en` is the most reliable; non-English is best-effort.
- Only call numbers you're authorized to — real calls ring real phones.
  US destinations only; every call discloses it's a recorded AI call.

**Full reference:** [`skills/callwright/SKILL.md`](./skills/callwright/SKILL.md) (Claude Code) · [`AGENTS.md`](./AGENTS.md) (Codex).

**Live API docs:** <https://api.voygr.tech/docs> — log in with your callwright key (the same one you set as `CALLWRIGHT_API_KEY`).
