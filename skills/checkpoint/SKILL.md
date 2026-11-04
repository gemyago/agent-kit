---
name: checkpoint
description: "Preserve useful conversation context through numbered checkpoints and forks, leaving intermediate exploration behind. Use when the user asks to mark a checkpoint or resume from one with distilled findings."
---

# Checkpoint

Separate marking a resume point from carrying later findings back to it.

- **Mark:** Use the next number in the active conversation, starting at 1.
  Identify the exact message boundary, including before/after for retrospective
  checkpoints. Include the overall goal in Checkpoint 1; repeat it only if changed.
- **Distill:** Summarize what was learned after the chosen checkpoint using the
  next number and the template below. Preserve outcomes, essential rationale,
  constraints, and useful exact references. Label uncertainty. Omit exploration,
  abandoned approaches, empty sections, and facts already retained before the
  fork point. Keep enough detail to continue without rediscovery.
- **Resume:** Fork from the chosen boundary and append the new checkpoint there.
  Report the destination and continue there only as requested. The new checkpoint
  becomes the next resume point. Do not fork the exploration's latest message
  and claim its history was removed.

Use available harness tools:

- If they only fork the latest history, save an idle fork at each clean
  checkpoint before exploring and record its chat ID. Explore in the original
  chat; keep the fork idle until you send it the distilled checkpoint, then
  continue in that fork.
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
