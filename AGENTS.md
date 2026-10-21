# Development notes

- Continue the native Godot game in this repository. Keep npm dependencies, the .NET SDK, and their caches project-local; use `scripts/godot.mjs` for the current editor path and environment.
- Record each completed development milestone in **Japanese** under `docs/devlog/`. Include concrete changes, decisions, observed bugs and fixes, exact verification results, and limitations useful for a later blog post.
- Keep actual runtime screenshots under immutable version folders in `docs/devlog/screenshots/`. Capture from the game, label fixture/demo scenes honestly, and retain previous versions for comparisons. Current README screenshots may also live in `docs/screenshots/`.
- Keep the Japanese blog draft in `docs/blog/` consistent with the code and recorded evidence. Do not invent timings, claim to have watched an entire video when only samples were inspected, or claim untested platforms work.
- Run the relevant checks before completing a milestone. The user has requested milestone uploads to `https://github.com/zhanghang211202/godot-ai-agent-demo`; commit and push completed, verified work there.
- Do not commit `.tools/`, `.godot/`, `node_modules/`, local MCP routing/configuration, credentials, or player saves.
- Development records and blog text are Japanese; retain the existing Chinese game UI unless the user requests a language change.
- Use `docs/requirements.md`, `docs/development-plan.md`, and `docs/art-direction.md` as the current product, milestone, and visual baseline. `docs/demo-plan.md` is historical v0.1 scope. Keep planned features distinct from implemented behavior.
- Next development milestone is M1 / v0.3: layout/asset interfaces, then a running hero + slime + sword/shield/whetstone art sample before expanding assets. Preserve the current rule/content budget during that milestone; new status effects and enemy mechanics belong to M2 / v0.4.
