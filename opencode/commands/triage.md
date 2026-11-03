---
description: Triage a GitHub issue — label, assign, find duplicates, suggest next action.
model: ollama/qwen3.8:27b
agent: plan
---

Review this issue and triage it:

!`gh issue view $1 --json title,body,labels,state,assignees,reactions,comments`

Label if appropriate, suggest next action, and check for duplicates.
