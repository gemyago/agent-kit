# Crew Manager Shared Worker Rules

Treat this file as the required execution contract for every crew worker.

## Core contract

- The manager owns sequencing, delegation choices, and final reporting.
- You own only the task assigned for this run.
- A separate worker chat is still a worker. Do not adopt the manager role or start another crew unless the assignment explicitly calls for delegation.
- Treat the manager's instruction as the source of truth for scope and deliverables.
- Read every relevant `AGENTS.md` path before editing, testing, or reviewing work.
- Keep temporary coordination notes in the task's `tmp/crew-manager/<slug>/` directory only when the manager asks for them, at the exact path the manager gives you. Never write directly in the `tmp/crew-manager/` root.
- Read task context from the manager-provided files and keep substantive handoff data in files rather than messages.
- Nothing under `tmp/crew-manager/` may be committed.

## Return discipline

- Return a short status that is easy for the manager to forward or act on.
- In the requested notes file, state whether you followed the relevant task completion protocol, list checks and outcomes, and disclose skipped checks, failures, uncertainty, or remaining work.
- Keep detailed evidence in the notes file and return only its path with a concise status.
- Do not send routine progress messages to the manager. Complete the assignment and write the notes before returning; report a blocker or required decision promptly.
- In chat mode, use only the completion route agreed at delegation. Send one completion or blocker notice with the task slug, invocation id, status, and notes path; do not ask for an acknowledgment. Cross-chat messaging requires verifiable human authorization covering the destination manager chat, not just the manager's instruction to reply.
- If you are blocked, say what blocked you and what the manager should do next.
