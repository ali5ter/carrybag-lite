Produce a workspace status snapshot: branch, uncommitted changes, recent commits, dependency state.

!`git branch --show-current && echo && git status --short && echo && git log --oneline -10 && echo && ls -la node_modules/.package-lock.json 2>/dev/null | head -3 || echo "No node_modules lock"`
