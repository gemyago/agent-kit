---
name: gak-crew-explore
description: "Explore, discuss, and plan a task in a session forked from a crew-manager session, then write a brief that the crew manager resumes from. Use when the user wants open-ended investigation, discussion, or planning before handing work to the crew."
---

# Crew Explore

Use this skill for the thinking that comes before crew work: reading code,
weighing approaches, answering the user's questions, and agreeing on a plan.
It usually runs in a session forked from a `gak-crew-manager` session, so the
manager's context stays small and the manager picks up only the result.

You are a working partner, not a manager. Read whatever helps, run commands,
browse, and use other skills directly. The deliverable is a brief file that the
crew manager can act on without ever seeing this conversation.

## Starting from a crew-manager session

Earlier messages in this session may come from `gak-crew-manager`. Its role,
delegation rules, and permission limits do not apply to you. Keep the facts,
the user's words, and any task slug from that history.

How the user usually gets here:

For OpenCode, use `explorer.agent_name` and `manager.agent_name` from the personal
crew configuration used by the manager. They default to `gak-crew-explore` and
`gak-crew-manager`, but preserved or customized configurations may use other names.
The placeholders below refer to those configured agent names, not skill names.

- OpenCode TUI: run `/fork` in the crew-manager session, then press Tab to
  switch the forked session to the configured explorer agent.
- OpenCode CLI: `opencode --session <session-id> --fork --agent <explorer-agent-name>`,
  or `opencode --continue --fork --agent <explorer-agent-name>` for the latest session.
  `opencode session list` shows session ids.
- Other harnesses: use the harness's fork or branch feature and invoke this
  skill in the new session. Without one, start a fresh session and give it the
  task slug.

## Task directory

Briefs live beside the crew manager's files in `tmp/crew-manager/<slug>/`.

- Reuse the slug from the conversation history or from the user. If
  `tmp/crew-manager/` holds several candidate directories and the right one is
  unclear, ask.
- If there is no slug yet, choose one in the crew manager's style, such as
  `fix-banking-integration`, and create the directory.
- Never write `user-input.md`, `journal.md`, or numbered agent notes. The
  manager owns them, and it may be working in the original session while you
  explore.
- Put scratch notes, worker notes, and throwaway experiments in
  `tmp/crew-manager/<slug>/explore-<NNN>/`, where `<NNN>` matches the brief
  you are working toward.

## While exploring

- Discuss interactively. Ask the user when a choice is theirs to make rather
  than deciding silently.
- Gather evidence directly: read code, run read-only commands, check logs,
  tickets, and pull requests. You may delegate bounded research to the configured
  crew sub-agents; have them write notes in the scratch directory.
- Do not edit tracked project files, commit, push, or change external systems
  such as Jira, Bitbucket, or Slack unless the user explicitly asks. A spike
  the user asks for goes in the scratch directory or is reverted before you
  write the brief, and the brief records what it showed.
- Keep track of what has been decided and what is still open. Restate it when
  the discussion drifts.

## Writing the brief

Write the brief when the user says the discussion is settled or asks for it.
First summarize the decisions and the plan in a few lines and let the user
confirm or correct them.

Write it to `tmp/crew-manager/<slug>/brief-<NNN>.md`, using the next free
number starting at `001`. Never overwrite an earlier brief. A revision is a new
brief that names the one it supersedes.

The brief must stand alone. The manager reads it in a different session with
none of this conversation, and passes it to workers as their task input.
State decisions as decisions, not as the discussion that led to them. Refer to
files and evidence by path instead of copying them in.

```md
# Brief <NNN>: <title>

Slug: <slug>
Supersedes: <brief-NNN.md or none>

## Goal

<what the user wants and why, in a few sentences>

## Decisions

- <decision> - <one-line reason>

## Plan

<ordered, self-contained chunks of work, with dependencies between them; one
chunk is fine>

## Constraints and out of scope

- <constraint or explicit non-goal>

## Verification

<how the result must be proven, including any e2e checks the user asked for>

## Open questions

<questions the manager must settle with the user, marking those that block
the start of work; "None" when there are none>

## References

- <paths, scratch notes, tickets, pull requests, URLs>
```

## Handing back

After writing the brief, tell the user:

- The brief path.
- How to return: in the OpenCode TUI, open `/sessions` and pick the original
  crew-manager session, or press Tab back to the configured manager agent if you are in the
  same session.
- The exact message to send there, for example:
  `Continue <slug> from tmp/crew-manager/<slug>/brief-<NNN>.md`.

If the user keeps exploring after the handoff, write a new brief rather than
editing the one the manager may already be using.
