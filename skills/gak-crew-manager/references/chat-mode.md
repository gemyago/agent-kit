# Separate worker chats

Chat mode delegates work to separate worker chats, threads, or sessions. It
uses capabilities such as starting a new chat or session, sending follow-up
messages, receiving completion or blocker handoffs, changing chat titles,
updating read status, or archiving or closing finished chats.

Use this mode with harness-provided tools or skills that define how to work
with separate chats or sessions. If a harness skill uses a CLI, run that CLI as
described by the skill while keeping crew-manager's task files, profiles, and
verification rules. Obtain task-level authorization when the harness requires
it.

- Required capabilities: starting a separate worker chat or session and
  receiving its completion or blocker handoff.
- Optional, harness-dependent hygiene: title prefixes, turn-ID waits, manual
  read-status clearing, and manual archiving or unarchiving. Apply these
  optional rules when the harness supports them and does not already manage
  them automatically.

## Titles and assignments

When the harness supports renaming chats and does not manage status labels
automatically, use one base title for the manager and children. The manager
replaces its status prefix before yielding:

| Prefix | Meaning | Read status |
| --- | --- | --- |
| `[working]` | Work can continue without user input. | The newly assigned child clears it after delegation. |
| `[needs you]` | User action is required. | Unread. |
| `[done]` | Work and required verification are complete. | Unread. |

Name children `[child] <base title> - <invocationId padded to four digits>`.
If the base changes, update all task chats and preserve their prefixes and IDs.

Create a fresh chat per assignment and always for independent verification.
Reuse it for corrections to that assignment, reopening or unarchiving it before
a follow-up when needed. Use the intended project and checkout, confirm access
to the shared files, and do not create a worktree merely because the chat is
separate.

Include the manager ID and host (when applicable), the notes path, and
completion route. When the harness requires authorization, include a reference
to the original human authorization and have workers verify it before messaging
the manager. Include the delegation turn ID when available and assign one child
to clear it.

When a new child chat is started, do not wait for its completion. The child
notifies the manager when it is done.

## Handoff

The worker writes its notes, sends one concise notice with the slug, invocation
ID, status, and notes path, then finishes. Include the worker turn ID when
available. A blocker notice states the required decision or action. If the
harness provides a native question/reply pause for mid-task clarifications, the
worker may use it when blocked; after sending a final handoff, finish without
waiting for the parent's reply or completion.

The manager yields after delegation when no independent work remains and resumes
on the notice. Read the notes and update the journal. Ignore duplicate notices.
Do not reread the worker's transcript for the handoff.

If callbacks are unavailable, arrange a completion wait or user-mediated handoff
before delegation. Do not substitute progress polling or promise automatic resumption.

## Read status and archiving

Apply this section when the harness exposes manual read-status or archive
controls and does not handle them automatically. Turn completion can make a
chat unread again. Wait for the relevant turn to finish. Immediately before a
read or archive update, check that no newer turn is active or completed.

- At startup, the assigned child waits for its parent's delegation turn to finish. Confirm it is still the latest turn and the title starts with `[working]`, then mark the parent read and begin work.
- After reviewing a handoff, the parent waits for that child's turn to finish and confirms it is still the latest turn. Mark the child read and archive or close it when supported.

Use completion events or bounded waits for those specific turns, not fixed sleeps
or progress polling. The child never waits for the parent after sending its
final handoff, so these waits cannot form a circular dependency. If tools or
matching-turn evidence are missing, skip that update and continue the assignment.
Do the same if authorization required by the harness is missing. Never clear a
parent marked `[needs you]` or `[done]`.
