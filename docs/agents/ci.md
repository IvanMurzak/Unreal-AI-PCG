# CI

CI ships as `*.yml-sample` and is activated by `commands/init`. It mirrors the Unity extension CI,
adapted to Unreal: a reusable per-UE-version test workflow, a PR aggregator, a version-gated atomic
release, and a manual bump workflow.

## Workflows

| File | Trigger | Purpose |
| --- | --- | --- |
| `test_unreal_plugin.yml` | `workflow_call` / dispatch | Build the plugin via UBT against the host project + run UE Automation specs for ONE UE version; parse the exported `index.json` (authoritative, not the editor exit code). |
| `test_pull_request.yml` | PR | Calls the reusable test per UE version (matrix **5.6 / 5.7**) + an **E2E** job: `unreal-mcp-cli install-extension` → headless boot → `run-tool` per tool (`Tests/e2e`). |
| `release.yml` | push to `main` | **Version-gated** on the `.uplugin` `VersionName` bump + tag (`v<version>`)-not-exists → full tests → package the **source zip** `<Module>-<version>.zip` → **atomic** GitHub Release. |
| `bump_version.yml` | manual | Runs `commands/bump-version.ps1`, pushes `release/<v>`, opens a PR. |

## Self-hosted runner gating (never red-by-absence)

The UBT/Automation/E2E legs run on a **self-hosted Windows UE runner** (labels
`[self-hosted, windows, unreal-<ue>]`, e.g. `unreal-5-7`; label each runner with one `unreal-X-Y` per UE version
installed on its machine, so a job only lands where its engine exists). They are gated so they **skip** — never fail a PR — until you
register a runner and set repository variables:

| Variable | Enables |
| --- | --- |
| `UNREAL_RUNNER_READY = true` | `test_unreal_plugin.yml` (UBT build + Automation) and `release.yml` build/test legs |
| `UNREAL_E2E_READY = true` | the E2E `install-extension` + tool-invocation job in `test_pull_request.yml` |
| `UNREAL_HOST_PROJECT` | absolute path on the runner to **this repository's own** host `.uproject`, e.g. `C:\actions-runner-unreal\host-<repo>\UnrealTestProject\UnrealTestProject.uproject` (the Automation pass junctions this extension into its `Plugins/`, junctions the **UnrealMCP core plugin** from a sibling `UnrealMCP-src` clone, and builds the host editor target). See "Host project isolation" below. |
| `UNREAL_HOST_TEMPLATE` (optional) | host project dir a missing `UNREAL_HOST_PROJECT` is bootstrapped from; default `C:\actions-runner-unreal\host\UnrealTestProject` |

## Host project isolation

Several repositories run UE jobs on the same machines: every `Unreal-AI-*` extension and the
Unreal-MCP core CI. A job mutates its host project (the `Plugins\UnrealMCP` junction, the sibling
`UnrealMCP-src` clone, `Intermediate`), so a host shared between repositories breaks concurrent jobs
(`Failed to (re)create host junction`) and leaks extension junctions into whatever opens that host
next (the core's tool-contract smoke). GitHub `concurrency:` groups are per repository and cannot
serialize across repos, so isolation is by path instead:

- `UNREAL_HOST_PROJECT` is per repository (`host-<repo>`). Each repository registers one runner per
  machine, so each host has exactly one writer. If you add a second runner for the same repository
  on one machine, it needs its own host too.
- `test_unreal_plugin.yml` refuses the shared template path and, when the host is missing, copies the
  template's `Source/`, `Config/` and `.uproject` into place (not `Content`, which the core's specs
  write assets into; not `Binaries`, `Intermediate`, `Saved`, `DerivedDataCache` or `Plugins`).
  Disk cost: one host `Intermediate`
  (~2.5 GB per UE version, mostly the UnrealEd shared PCH) plus one `UnrealMCP-src` clone per repo.
- The job's always-run cleanup unlinks its own `Plugins\<Module>` junction (the link only, never the
  target), so no extension junction outlives its job.
- Processes: `.github/scripts/stop-host-processes.ps1` stops every process whose command line references
  this repository's host dir (UnrealEditor-Cmd, UBT, ShaderCompileWorker, the E2E server) plus its
  descendants. It runs before the build, to clear what an interrupted earlier run left behind, and again
  in the always-run cleanup. Per-repo hosts guarantee it never matches another repository's job.
  Persistent workspaces and build caches (`Intermediate`, `Binaries`, DDC, `UnrealMCP-src`) are kept on purpose.

Fork PRs never run on the self-hosted runner (`head.repo.full_name == github.repository` guard); a
fork PR's checked-out code must not execute on your machine.

## The multi-UE-version matrix

`5.6 / 5.7` is the analog of Unity's multi-version test matrix — it validates the extension on each
supported engine (the `test_unreal_plugin.yml` legs). The **release ships ONE source zip** (not a
per-UE binary): the extension ships as source and UE compiles it on the consumer's editor open, so a
single source asset serves every UE version (the compile-on-install decision, design note §5).
A `BuildPlugin -Rocket` per-UE binary would require `UnrealMCP` engine-installed on the runner — see
`release.md`.

## E2E = a cross-dependency on the install layer

The E2E job consumes `unreal-mcp-cli install-extension` (the T1 install capability). In CI it
installs from the local checkout via `--source` (offline/CI escape hatch — mirrors `godot-cli`),
boots a headless editor, waits for `tools/list`, then runs `Tests/e2e/Run-ToolChecks.ps1`, which
calls `unreal-mcp-cli run-tool <tool>` per check and asserts a well-formed JSON success. If the CLI
command is not yet published when you enable E2E, this leg documents the contract the CLI must meet.
