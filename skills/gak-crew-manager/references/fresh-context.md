# Continue in a fresh manager session

Use this procedure when the user requests fresh context. Create a new chat or
session with a concise handoff. Never use a history fork for this request.

## Prepare the handoff

Capture the original exact title before changing it. Write one durable
`fresh-context.md` under the existing `tmp/crew-manager/<slug>/` directory.
Include enough context to continue the objective without reading the transcript.

- State the objective, current phase, and next authorized action. Distinguish completed, failed, deferred, and outstanding work.
- Record approved scope, permissions, exclusions, and the original human authorization reference for chat actions.
- Give the host, project, explicit checkout, task slug, session mode, and configuration path. Preserve configured models and supported settings.
- Record each relevant repository's branch, HEAD, staged and uncommitted state from current evidence. Delegate a state check if needed under the manager's scope rules.
- Link the task files, authoritative references, and completed worker evidence. Keep sensitive credentials out of the handoff.
- List worker IDs and hosts, invocation IDs, assignments, notes paths, completion routes, and which handoffs were already consumed.
- Record the original manager ID and title, its handoff turn ID when available, and who owns continuation. Add the successor ID or session path once ready.

Update the journal to point to this handoff. If the latest objective is already
complete, record that outcome and make reporting it the successor's next action.

## Preserve active assignments

Prefer a completion boundary before creating the successor. Use completion
events or supported bounded waits for specific assignments, renewing quietly
when needed. Read notes after their completion or blocker handoff as usual.

If an assignment remains active, preserve its worker and completion route.
Transfer the route only when supported and covered by the task's human chat
authorization. Otherwise, an authorized old chat can relay completion notices
to the successor. Record that route in the handoff. If neither route is available,
keep the original manager as owner until completion or a manual handoff is ready.
Session-bound native subagents need a completion boundary unless the harness
supports their transfer. Never spawn replacements for these assignments.

## Create the successor and transfer ownership

Use supported fresh-session controls on the same host and project, with the same
explicit checkout and session mode. Reuse the task directory and configuration.
Do not create a worktree or repeat completed side effects because context is new.
Pass only the handoff path and the minimum authoritative references.

The startup prompt must tell the successor to read the handoff and wait for the
old manager's handoff turn to finish before acting. Use a supported completion
event or bounded wait for that turn. Then confirm that the handoff names this
successor as owner. If completion or ownership cannot be confirmed, report the
missing evidence and leave execution with the original manager.

In chat mode, give the successor the original exact title. Wait for a ready
result with a usable ID and confirm access to the task files and checkout.
Record the successor and transfer ownership in the handoff and journal. Then
replace only the old manager's status prefix with `[handed off]`, preserving the
base title. For example, the old `[working] AGT-946 eval package` becomes
`[handed off] AGT-946 eval package`. The successor keeps
`[working] AGT-946 eval package`. Finish the old manager's handoff turn.
Do not implicitly archive or delete the old chat.

If creation fails, remains pending, or required controls are unavailable, keep
the original title and ownership. Report the handoff path and any partial
successor ID. Give the user a manual route to open a fresh session in the same
host, project, and checkout, then pass that path. Record ownership and the title
change once the manual successor is ready. Check any partial creation before
retrying so only one successor can begin work.

## Resume and handle late notices

The successor continues already authorized unfinished work from the handoff.
Verify current state before repeating a retryable side effect. If the objective
is complete, report it without creating additional assignments. Preserve the
recorded permissions and use the existing delegation and verification rules.

After ownership transfers, the old chat only relays late completion
notices through the agreed authorized route. It does not resume execution or
assign work. Include the slug, invocation ID, status, and notes path in a relay.
The successor owns journal updates and records consumed notices to ignore
duplicates, including notices already handled by the old manager.
If relay tools are unavailable, report the notice and provide the successor
location for a user-mediated handoff. Keep the existing matching-turn checks
before read-status or archive updates. A `[handed off]` title never qualifies
for the child's `[working]` parent read update.
