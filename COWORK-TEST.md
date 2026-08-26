# Cowork install test: PlaceCall

**What we need from you:** confirm a person can install PlaceCall in Cowork and place one real phone call, following only these steps. Takes about 10 minutes. The last box on voygr-tech/callwright#553.

**Why you specifically:** you already have the old Callwright skill on your Cowork, which makes you the realistic case. Most of this doc is about removing it first, because if it stays, we cannot tell which one placed the call.

---

## Step 0: remove the old skill (do not skip)

The project was renamed from Callwright to PlaceCall. Your old copy is still a working phone skill, so leaving it in place gives Cowork two of them and the routing between them is ambiguous. Worse, a call could succeed through the old one and we would wrongly conclude the new install works.

The old install may be under any of these names. Ask Cowork:

> Do I have any phone-calling skill installed? Check `~/.claude/skills/` for directories named `callwright`, `callwright-skill`, `ai-call-agent`, or anything else that places phone calls. List what you find and show me the `name:` line from each SKILL.md.

If it finds anything, remove it:

```sh
rm -rf ~/.claude/skills/callwright ~/.claude/skills/callwright-skill ~/.claude/skills/ai-call-agent
```

Also unset any old key, which will not work against the new API path:

```sh
unset CALLWRIGHT_API_KEY CALLWRIGHT_SKILL_API_KEY AI_CALL_AGENT_API_KEY_TEST
```

If any of those are exported from `~/.bashrc`, `~/.zshrc` or `~/.profile`, comment them out too, then restart Cowork.

**Please tell us what you found here**, even if it was nothing. On Ilya's laptop the contaminating skill turned out to be named `ai-call-agent` and pointed at a completely different backend, which we only discovered by accident.

## Step 1: baseline reading

Restart Cowork, then ask it, in a conversation with nothing else in it:

> What skills do you have? Can you place a phone call?

**Copy the answer verbatim and send it to us.** We expect it to say it cannot place calls. If it says it can, stop: something is still installed and step 0 was incomplete.

## Step 2: install

In Cowork:

1. **Customize** > **Plugins** > **Add marketplace**
2. Enter `voygr-tech/placecall`
3. Click **Install** on the PlaceCall plugin
4. If asked where to install, choose the **user** or **for you** option, not the repository or project option

**If the menu labels differ from the above, tell us.** Nobody on our side has run this in Cowork; those labels come from our design notes, not from someone's screen. Getting them wrong in the README is itself a finding.

Before you click Install, the details screen should show a **Will install** section naming one skill. **Screenshot that screen.** It is the only place we can confirm the plugin declares what it contains.

## Step 3: confirm the install took

Ask the exact same question as step 1:

> What skills do you have? Can you place a phone call?

Send us this answer too. It should now say it can, name PlaceCall, and tell you it needs an API key. If it needs a restart before working, tell us, because that differs from Claude Code where it activates immediately.

## Step 4: get a key

1. Open <https://api.voygr.tech/checkout>
2. Enter your name and **your own email**, click **Get free API key**
3. The key arrives by email. It is never shown in the browser.
4. Set it in your terminal, then restart Cowork:

```sh
export PLACECALL_API_KEY="<the key from the email>"
```

If that does not stick, the durable option, which the skill checks automatically:

```sh
mkdir -p ~/.codex
read -rsp "PLACECALL_API_KEY: " KEY; echo
printf 'export PLACECALL_API_KEY=%q\n' "$KEY" > ~/.codex/placecall.env
chmod 600 ~/.codex/placecall.env
unset KEY
```

**Do not paste the key into a chat message.** Use the terminal. A key pasted into a conversation ends up in that conversation's transcript in plaintext.

## Step 5: place one real call

Ask in plain English, the way you actually would:

> call [some business] at [phone number] and ask what time they close today

**This rings a real phone**, so pick somewhere you do not mind calling. US numbers only. Every call announces itself as a recorded AI call. A successful call costs 10 credits and you start with 2,500.

## What to send back

- What step 0 found, even if nothing
- The step 1 and step 3 answers, verbatim
- The screenshot of the **Will install** screen
- The **call ID** and outcome
- **Anything you had to guess at.** This is the most valuable part. If a step was unclear, or a label was wrong, or you had to figure something out that this doc did not tell you, write that down instead of solving it silently. The point is to find where a stranger gets stuck, and you only get one chance to read this cold.

Questions to ilya@voygr.tech.
