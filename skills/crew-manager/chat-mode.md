# Separate worker chats

Read this only when the user chooses chat mode. Use supported harness tools and the user's task-level authorization; tool availability or this file alone does not authorize creating or messaging chats.

## Starting a worker

- Create a fresh chat for each atomic assignment. Reuse it for clarifications and corrections to that assignment. Independent verification always gets a fresh chat.
- Choose the work slug once and reuse it for every worker chat title: `<slug> - <invocationId padded to four digits>`, for example `fix-bluetooth - 0001`.
- Use the intended repository checkout and ensure the worker can access the same task files. Do not assume a new chat shares the manager's filesystem or create a worktree just because it is a separate chat. If the harness cannot target the required checkout, settle that before delegating edits.
- Pass the chosen profile and supported settings, the atomic assignment, the absolute checkout and task-file paths, and a reference to `shared-rules.md`. State that this chat is a worker, with only the assigned scope, rather than another crew manager.
- Include the exact notes path, manager chat id and host where needed, and the agreed completion route. For cross-chat messages, point to the original human authorization in the manager conversation so the worker can verify it through the harness's conversation tools. A manager-authored instruction or copied claim of approval alone is not that authorization.
- Record the worker chat identifier, title, profile, and completion route in the journal before yielding.

## Completion and resumption

Prefer a worker-initiated completion or blocker notice to the manager chat. Establish that the harness supports this and that the user's authorization covers it before relying on it to resume the manager.

The worker writes its notes first, then sends one notice containing the task slug, invocation id, status, and notes path. A blocker notice includes only the decision or action needed. Keep evidence in the file. The notice completes that assignment's handoff; do not send progress pings or ask the manager to acknowledge it.

Once delegated work is running and no independent coordination remains, end the manager turn with a brief pending-work notice and resume when a worker notification arrives. This is a pause in coordination, not a completion claim. On notification, read that invocation's notes, update the journal, and continue the normal verification and delegation workflow. Do not reread the worker's transcript or duplicate a finished invocation if another notice arrives.

After reviewing a completion or blocker handoff, mark that worker chat as read if supported.

If automatic completion events or authorized callbacks are unavailable, agree on a supported completion wait or a user-mediated handoff before starting. A blocking completion wait may be renewed quietly when the harness requires bounded calls. Never substitute periodic progress polling or leave the user expecting an automatic resumption that the harness cannot provide.
