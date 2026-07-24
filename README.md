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

## Set your key (required to place calls)
Installing the skill does **not** need a key; **placing calls does.** Get a team key
from the organizers, then set it in your shell.

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
- Each call ≈ **10 credits** (`GET /v1/usage` for your balance; `402` when out).
- After a call `completed`, **wait ~30s** before reading `GET /calls/{id}` — the
  outcome/transcript populate a bit *after* the status flips.
- `en` is most reliable; other languages are best-effort.
- Only call numbers you're authorized to — real calls ring real phones.

**Full reference:** [`skills/callwright/SKILL.md`](./skills/callwright/SKILL.md) (Claude Code) · [`AGENTS.md`](./AGENTS.md) (Codex).

**Live API docs:** <https://api.voygr.tech/docs> — log in with your callwright key (the same one you set as `CALLWRIGHT_API_KEY`).
