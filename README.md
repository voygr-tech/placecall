# PlaceCall - give your agent a phone ☎️

**Two API endpoints: one finds who to call, one places a real phone call.** Hand
`POST /calls` a number and a plain-English task; PlaceCall dials it, talks to
whoever answers, works through menus/hold, and returns a structured result + full
transcript. No number yet? `POST /v1/places/suggest` turns "book a romantic
restaurant in Chicago Saturday 8pm" into ready-to-dial place cards - phone,
reasoning, and a ready-made call brief - free of charge. It's how your agent
reaches the ~80% of businesses that have a phone, not an API - inquiries, booking,
lead-gen, appointment-setting.

```sh
curl -s -X POST https://api.voygr.tech/calls \
  -H "X-API-Key: $PLACECALL_API_KEY" -H "Content-Type: application/json" \
  -d '{"target_phone":"+1XXXXXXXXXX","brief":"Call this restaurant and ask what time the kitchen closes tonight.","language":"en"}'
```

## Install
Installing the skill needs **no key** - it just teaches your agent how to call the
API. You add your key separately (next section) before placing real calls.

### Claude Code (recommended)
Two commands, no shell, no git - and it **auto-updates** from this repo:
```
/plugin marketplace add voygr-tech/placecall
/plugin install placecall@placecall
```
Claude Code asks where to install it - choose **user scope** ("Install for you")
unless you specifically want it confined to one repository. The skill then answers
to `/placecall:call`, and Claude reaches for it on its own whenever you ask to
call someone.

### Claude Code, without the plugin
```sh
git clone https://github.com/voygr-tech/placecall && cd placecall
./install.sh     # copies skills/call/SKILL.md -> ~/.claude/skills/placecall/
```
`install.sh` is a tiny convenience script - it **only** copies
`skills/call/SKILL.md` into your skills dir (no network, no other side
effects); you can also copy it by hand. Then start a **fresh** Claude Code session
(skills load at startup). Note that a copy never updates itself - if you want new
skills and fixes as we ship them, prefer the plugin above.

### Cowork
Same package as the Claude Code plugin, no terminal at all:

1. **Customize** > **Plugins** > **Add marketplace**
2. Paste `voygr-tech/placecall`
3. Click **Install** on the PlaceCall card

Auto-updates from this repo, like the Code plugin. Add your key the same way as
everywhere else (next section).

> **Not claude.ai Chat.** Plugins reach Claude Code and Cowork. They do not add
> anything to Claude chat conversations. The API is still just HTTP, so any agent
> with a shell can use it (see "Any agent / plain shell" below).

### Codex
**Type this inside Codex, not in your shell.** `$skill-installer` is a system
skill bundled with Codex, so there is nothing to set up first:

```
$skill-installer install the skill at https://github.com/voygr-tech/placecall/tree/main/skills/call and name it placecall
```

It is a skill rather than a command, so plain English works and is what it
expects. It runs the install for you and reports where the skill landed. **No
restart needed**, it is available on your next turn, and it answers to
`$placecall`.

If the phrasing above is not understood, this is the script it runs, and you can
run it yourself from a normal shell:

```sh
python3 ~/.codex/skills/.system/skill-installer/scripts/install-skill-from-github.py \
  --url https://github.com/voygr-tech/placecall/tree/main/skills/call \
  --name placecall
```

Two things worth knowing. The installer refuses to overwrite, so if you already
have a `placecall` (or older `callwright`) skill in `~/.codex/skills`, delete it
first or the install aborts. And **don't** run `install.sh` on Codex, that is the
Claude Code path.

On older Codex without `$skill-installer`, or as an alternative on any Codex,
paste this repo's [`AGENTS.md`](./AGENTS.md) into your project's `AGENTS.md`.

### Any agent / plain shell
No install needed - the API is just HTTP. `skills/call/SKILL.md` is the full
reference; a model with a shell tool can place calls straight from it.

## Get a key (self-serve) and set it
Installing the skill does **not** need a key; **placing calls does.** Keys are
**self-serve** - no need to contact anyone:

1. Open <https://api.voygr.tech/checkout> and click **"Get free API key"**
   (name + email).
2. The key arrives **by email** (it is never shown in the browser or API
   response). Free tier: **2,500 credits** (250 successful calls) with a
   25-calls/day cap. **Any credit purchase lifts the cap to 5,000/day** -
   once you've paid, credits are your only practical limit.
3. Lost the key? <https://api.voygr.tech/recover> emails you a new one.
4. Need more credits? Top up on the same <https://api.voygr.tech/checkout>
   page (Stripe-hosted payment).

Then set the key in your shell:

**Quick way** - just export it for the current session:
```sh
export PLACECALL_API_KEY="<your key>"
```

**Nicer way** - save it once (no echo to screen, `600` perms) and load it per session:
```sh
mkdir -p ~/.codex
read -rsp "PLACECALL_API_KEY: " KEY; echo
printf 'export PLACECALL_API_KEY=%q\n' "$KEY" > ~/.codex/placecall.env
chmod 600 ~/.codex/placecall.env
unset KEY
# then, in any new shell where you want to place calls:
source ~/.codex/placecall.env
```

**Verify** (prints your quota, never the key):
```sh
curl -s -H "X-API-Key: $PLACECALL_API_KEY" https://api.voygr.tech/users/me
```
Never commit `~/.codex/placecall.env` or paste the key into chat - keep it in the
env var / the `600` file above.

## Installed this before August 2026?
This project was called **Callwright** until 2026-08, and the repo lived at
`voygr-tech/callwright-skill`. Two things to know:

- **Your existing setup keeps working.** `install.sh` copies the skill rather than
  linking it, so an older copy is frozen at whatever it was when you installed -
  the rename cannot break it. It also means it will never pick up new skills or
  fixes, which is the reason to migrate.
- **To migrate, delete the old copy first.** It is still a working phone skill, so
  leaving it in place gives your agent two of them and the routing between them is
  ambiguous. `install.sh` now warns you if it finds one.
  ```sh
  rm -rf ~/.claude/skills/callwright ~/.claude/skills/callwright-skill
  ```
  Then install the plugin above, and re-export your key under its new name:
  `PLACECALL_API_KEY`. The key itself is unchanged - only the variable is renamed,
  so no need to reissue anything.

If you previously installed a phone-call skill from someone else (e.g.
`ai-call-agent`), remove or disable that too, for the same reason.

## The one rule
**Everything goes in the `brief`** - the bot reads only your brief. Put every detail
in it (what to ask, who you're calling for, names/dates/party size/callback number,
how to wrap up). One endpoint, describe the task, done.

## Good to know
- **Only successful calls are billed** (10 credits per `success_*` outcome;
  voicemails/hangups/no-answers are free). Each call takes a refundable
  **30-credit hold** at dial time (3× the charge, settled down to 10 on
  success) - under 30 available and `POST /calls` returns `402` even with a
  non-zero balance (`GET /users/me` for your balance; top-ups are self-serve
  at <https://api.voygr.tech/checkout>).
- After a call `completed`, the outcome/transcript can populate a moment
  *after* the status flips - poll `GET /calls/{id}` until `outcome_type` is
  non-null.
- 13 language codes accepted (`en`, `es`, `fr`, `de`, `hi`, `ru`, `pt`, `ja`,
  `it`, `nl`, `sr`, `tr`, `pl`) plus `auto` (the default, resolves to `en`).
  `en` is the most reliable; non-English is best-effort.
- Only call numbers you're authorized to - real calls ring real phones.
  US destinations only; every call discloses it's a recorded AI call.

**Full reference:** [`skills/call/SKILL.md`](./skills/call/SKILL.md) (Claude Code) · [`AGENTS.md`](./AGENTS.md) (Codex).

**Live API docs:** <https://api.voygr.tech/docs> - log in with your PlaceCall key (the same one you set as `PLACECALL_API_KEY`).
