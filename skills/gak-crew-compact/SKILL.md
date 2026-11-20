---
name: gak-crew-compact
description: "Compact an ongoing crew task into a numbered snapshot and continue it in a new manager session. Use when the user requests crew compaction or a new session with summarized task context."
---

# Crew compaction

Prepare a snapshot of an existing crew task so a new manager session can
continue it. Preserve the task's scope, permissions, configuration, and session
mode.

## Prepare a snapshot

Wait for active worker turns to finish using completion events or bounded waits.
Consume their completed notes and update the journal before switching sessions.
Record unfinished assignments and blockers for the next manager.

Reuse the task's slug and directory. Write
`tmp/crew-manager/<slug>/compaction-<NNN>.md`, using the next free number starting
at `001`. Keep earlier snapshots intact. Include enough context to
continue without the old transcript, linking existing task files and evidence
instead of copying them.

The snapshot carries the following context.

- The objective, approved scope, permissions, exclusions, and references to human authorization when required by the harness.
- Decisions and essential rationale, completed work and verification, failures, blockers, and outstanding work.
- The host, project, explicit checkout, known repository state and its evidence, configuration path, session mode, and configured models and settings.
- The task slug, original manager ID and title, journal and approved brief paths, worker notes, and next invocation ID. Distinguish consumed results from assignments needing follow-up.
- The next authorized action, including any decision needed from the user. If the objective is complete, make reporting its outcome the next action.

Include continuation instructions addressed to the new manager in the snapshot
itself. Tell it to read the linked task files, reuse the recorded slug, checkout,
configuration, session mode, permissions, and invocation sequence, and record its
session as the manager in the journal. Direct it to continue the next authorized
action and check current state through a worker before repeating a side effect.
If the objective is complete, direct it to report the recorded outcome.

Link the snapshot in the journal before starting the next session. Keep credentials
out of the snapshot and preserve the repository's rules for temporary files.

## Continue in a new session

Prepare this message with the actual slug and absolute snapshot path.

```text
Use gak-crew-manager and continue task <slug> from <absolute snapshot path>.
```

When the harness supports creating a new chat or session within the user's
authorization, start it with that message on the recorded host, project, and
checkout. Reuse the recorded configuration, session mode, supported settings,
and original task title. Disclose unavailable settings and use a supported
configured fallback. Use a new session with the snapshot as its task context.
When the harness selects agents by name, use `manager.agent_name` from the
recorded configuration.

After creation is confirmed, the new manager owns continuation. In chat mode,
replace only the old manager's status prefix with `[handed off]`. Report the
snapshot path and new session location, then finish the current turn. The new
manager continues from the snapshot on its first turn.

If creation is unavailable or fails, show the snapshot path and the same
paste-ready message. For manual continuation, use the recorded host, project,
checkout, and configured manager agent. If creation returned a partial session
ID, check its state and use that destination when it exists. Otherwise, tell the
user to open a new session. Resolve partial creation before starting another.

After preparing the snapshot, leave further task execution to the next manager.
A later request to continue in the old session needs a check of the journal and
any recorded successor to establish which session owns the task.
