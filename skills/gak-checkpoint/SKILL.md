---
name: gak-checkpoint
description: "Preserve useful conversation context through numbered checkpoints and forks, leaving intermediate exploration behind. Use when the user asks to mark a checkpoint or resume from one with distilled findings."
---

# Checkpoint

Mentioning that checkpoints will be used only opts into the workflow. Discuss
normally until the user explicitly asks to create one. Resuming an existing
checkpoint does not request the next one.

- **Mark:** Use the next number in the active conversation, starting at 1.
  Use the previous checkpoint as the source boundary, or the conversation's
  start for Checkpoint 1, unless the user chooses another position.
  Identify the exact message boundary, including before/after for retrospective
  checkpoints. Include the overall goal in Checkpoint 1; repeat it only if changed.
- **Distill:** Summarize the conversation from the source boundary through the
  request using the next number and the paste-ready template below. Preserve
  outcomes, decisions, essential rationale, constraints, and useful exact
  references. Label uncertainty. Omit exploration, abandoned approaches, and
  facts already retained before the fork point. Say if nothing remains open.
  Keep enough detail to continue without rediscovery.
- **Resume:** If supported, fork from the chosen historical boundary and append
  the new checkpoint there as part of the explicit request.
  Report the destination and continue there only as requested. The new checkpoint
  becomes the next resume point. Do not fork the exploration's latest message
  and claim its history was removed.

Use available harness tools:

- Never create a checkpoint or idle fork after each message, after exploration,
  or in anticipation of a future request.
- If the requested boundary cannot be forked automatically, give its exact
  manual location and a paste-ready checkpoint, then wait for the user to resume
  there.
- Ask only if the intended boundary is ambiguous; do not invent message IDs.
- Keep handoff instructions outside the checkpoint. Make **Next** substantive,
  even if the receiving chat should acknowledge and wait.

```markdown
## Checkpoint N

### Carry forward
- Established facts, decisions, and essential rationale.
- Relevant constraints and references.
- Changes to the overall goal, if any.

### Still open
- Unresolved questions and explicitly labeled assumptions.

### Next
- The immediate next step or direction.
```
