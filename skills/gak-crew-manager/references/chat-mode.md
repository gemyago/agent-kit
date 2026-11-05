# Separate worker chats

Use this mode only with supported tools and the user's task-level authorization.

## Titles and assignments

Use one base title for the manager and children. The manager replaces its status
prefix before yielding:

| Prefix | Meaning | Read status |
| --- | --- | --- |
| `[working]` | Work can continue without user input. | The newly assigned child clears it after delegation. |
| `[needs you]` | User action is required. | Unread. |
| `[done]` | Work and required verification are complete. | Unread. |

Name children `[child] <base title> - <invocationId padded to four digits>`.
If the base changes, update all task chats and preserve their prefixes and IDs.

Create a fresh chat per assignment and always for independent verification.
Reuse it for corrections to that assignment, unarchiving it before a follow-up.
Use the intended project and checkout, confirm access to the shared files, and
do not create a worktree merely because the chat is separate.

Include the manager ID and host, the notes path, completion route, and a reference
to the original human authorization. Workers must verify that authorization
before messaging the manager. Include the delegation turn ID when available and
assign one child to clear it.

## Handoff

The worker writes its notes, sends one authorized notice with the slug, invocation
ID, status, and notes path, then finishes. Include the worker turn ID when available.
A blocker notice states the required decision or action. Do not wait for the
parent's reply or completion after handoff.

The manager yields after delegation when no independent work remains and resumes
on the notice. Read the notes and update the journal. Ignore duplicate notices.
Do not reread the worker's transcript for the handoff.

If callbacks are unavailable, arrange a completion wait or user-mediated handoff
before delegation. Do not substitute progress polling or promise automatic resumption.

## Read status and archiving

Turn completion can make a chat unread again. Wait for the relevant turn to finish.
Immediately before a read or archive update, check that no newer turn is active
or completed.

- At startup, the assigned child waits for its parent's delegation turn to finish. Confirm it is still the latest turn and the title starts with `[working]`, then mark the parent read and begin work.
- After reviewing a handoff, the parent waits for that child's turn to finish and confirms it is still the latest turn. Mark the child read and archive it when supported.

Use completion events or bounded waits for those specific turns, not fixed sleeps
or progress polling. The child never waits for the parent after sending its
handoff, so these waits cannot form a circular dependency. If tools, authorization,
or matching-turn evidence are missing, skip that update and continue the
assignment. Never clear a parent marked `[needs you]` or `[done]`.
