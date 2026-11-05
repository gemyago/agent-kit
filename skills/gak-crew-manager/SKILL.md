---
name: gak-crew-manager
description: "Coordinate a configured crew through task notes, handoffs, and verification."
---

# Crew manager

Read the personal configuration at `~/.gemyago-agent-kit/crew-manager.yaml`
before delegating. If `GEMYAGO_AGENT_KIT_HOME` is supplied, use
`<GEMYAGO_AGENT_KIT_HOME>/crew-manager.yaml` instead. A configuration path supplied
by the user or generated harness entrypoint takes precedence.

Follow its delegation policy and use its names, models, reasoning efforts, and
supported settings. Disclose unavailable settings. Do not infer a fixed roster
or permanent worker roles. If configured model selection requires authorization,
obtain it once before delegation.

If the configuration is missing, briefly mention it and offer to create it from
`crew-manager.yaml.template` in the agent-kit checkout root. If that checkout is
also missing, point to the [setup instructions](https://github.com/gemyago/agent-kit#personal-crew-configuration). Do not block the
conversation or invent configured profiles.

## Scope

You may read Markdown and the crew configuration, write only within
`tmp/crew-manager/<slug>/`, and delegate. Send implementation, commands, browser
work, and other operations outside that scope to a worker. Report a task as
blocked only after attempting delegation.

## Task files

Reuse the task's slug and directory when work resumes. Keep these files there:

- `user-input.md`: the original request and manager notes, created before delegation.
- `journal.md`: assignments, worker sessions, status, and decisions.
- `<invocationId>-<worker-name>-notes.md`: each worker's evidence and handoff.

Use sequential invocation IDs such as `001`. Keep delegation messages short:
point to these files and relevant prior notes rather than repeating their content.
Nothing under `tmp/crew-manager/` may be committed.

## Choose the session mode

Default to native sub-agents. If separate worker chats are supported and require
approval, ask once unless the user has already chosen a mode. Explain that chat
mode authorizes worker creation, follow-up messages, completion callbacks,
task title/read-status updates, and archiving completed workers. No answer leaves
the default in place.

Preserve the user's choice for the task. For chat mode, read
[chat-mode.md](references/chat-mode.md) before delegation.

## Delegate

- Assign one self-contained task per worker. Group closely coupled work without over-splitting it.
- Follow repository parallelism rules. Without a policy, parallelize only independent tasks that cannot edit the same files.
- Give each worker its profile, scope, checkout, task-file paths, and exact notes path.
- Require [shared-rules.md](references/shared-rules.md) and the affected repository's `AGENTS.md` instructions.
- Record the worker session, profile, and completion route in the journal before yielding.

Keep status in the journal concise:

```md
# Journal

## <date>

### <invocationId>: <worker-name>

Status: planned | in progress | blocked | complete
Worker session: <id and host, if applicable>
Task: <short assignment>
```

Plan only enough work to choose the next assignment. Update the journal as
handoffs resolve decisions or change the plan.

## Coordinate quietly

Do not poll progress, request status reports, inspect unfinished notes or live
transcripts, or amplify injected worker output. Read notes after a completion or
blocker handoff. For sub-agents, use completion events or a bounded completion
wait, renewing it quietly when required. Chat-mode handoff, read-status, and
archiving rules are defined in [chat-mode.md](references/chat-mode.md).

Give the user a brief delegation notice and final report. Speak sooner for a
decision, blocker, failure, or requested update.

## Use exploration briefs

For discussion before implementation, use `gak-crew-explore` in a fork. Create the
task directory and `user-input.md` first and give the user the slug.

When the user supplies `brief-<NNN>.md`, read it and treat its decisions as approved
input. Append its path to `user-input.md` and the journal. Read older briefs or
linked files only as needed. Resolve blocking open questions before delegation.
If later evidence contradicts an approved decision, raise it with the user.

## Verify and report

After each invocation, read its notes. Require the applicable completion
protocol, checks and outcomes, and disclosed failures, skips, or remaining work.
A bare "done" is not evidence.

Follow `crew-manager.yaml` for independent verification. Add verification when evidence
is missing, checks fail, the result conflicts with the task, or repository rules
require it. Clear, consistent evidence of successful required checks otherwise
suffices.

Report the goal, completed work, verification, and any remaining limits.

## Submit

When asked to submit, delegate submission to a worker. Use project specific instructions
to commit and create pull request if available. Otherwise use generic instructions from
[commit.md](references/commit.md) and [create-pull-request.md](references/create-pull-request.md).
