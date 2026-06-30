<h1 align="center">Unreal AI PCG</h1>

<p align="center">
  A <b>Procedural Content Generation (PCG)</b> tool extension for
  <a href="https://github.com/IvanMurzak/Unreal-MCP">AI Game Developer (Unreal-MCP)</a>.
  Lets an AI agent list and inspect PCG graphs and assets, add and inspect PCG components on
  actors, and trigger PCG generation / refresh — all from inside the Unreal Editor.
</p>

---

**Unreal AI PCG** is an Unreal Engine **`Type=Editor` plugin** that implements the Unreal-MCP
contract `IUnrealMcpToolProvider` and contributes a focused family of MCP tools wrapping Unreal's
built-in **PCG** plugin. Unreal-MCP discovers the provider at boot (and live, when the plugin loads
later) and merges these tools into the advertised set, so an AI agent can drive procedural-content
workflows against the live editor. Enabling / disabling the extension live-updates what the AI sees.

> Authoring is **C++** (unlike Unity's C# `[McpPluginTool]`). The extension takes a compile-time
> dependency on the engine's `PCG` plugin — that dependency **is the gating**: the extension won't
> compile or load unless PCG is present in the host project.

## Tools

This extension contributes the following PCG tools (ids are kebab-case; the handler runs on the game
thread and calls PCG / editor APIs directly). Mutating tools validate engine state defensively and
return a structured error rather than crashing the editor.

| Tool | Kind | What it does |
| --- | --- | --- |
| `pcg-list-graphs` | read-only | List every PCG graph asset in the project (Asset Registry; no asset loaded). |
| `pcg-get-graph` | read-only | Inspect a single PCG graph asset: node count + per-node summary. |
| `pcg-add-component` | mutating | Add a `UPCGComponent` to an actor in the editor world, optionally bound to a graph. |
| `pcg-get-component` | read-only | Inspect the PCG component on an actor: bound graph, generation state. |
| `pcg-generate` | mutating | Trigger generation / refresh on an actor's PCG component. |

> The exact tool set is finalized in the implementation; each tool ships with one UE Automation spec
> and one E2E `unreal-mcp-cli` check. `extension.json` `tools[]` and this table are the source of truth.

## Install

Install into any UE project that has the **UnrealMCP core plugin** available (the project path is a
**positional** argument):

```bash
# From the published GitHub Release:
unreal-mcp-cli install-extension com.ivanmurzak.unreal-ai-pcg <UEProject>

# Offline / from a local checkout (no published release needed):
unreal-mcp-cli install-extension com.ivanmurzak.unreal-ai-pcg <UEProject> --source <path-to-this-repo>/UnrealAIPCG
```

The CLI resolves the release source zip (`releases/download/v<version>/UnrealAIPCG-<version>.zip`),
drops the plugin into `<UEProject>/Plugins/UnrealAIPCG/`, enables it **and** the gating `PCG` engine
plugin in the `.uproject`, and the editor compiles it from source on next open (or pass `--build` to
compile now via UBT). The same capability backs the AI-Game-Dev desktop app button and the in-editor
Extensions panel.

## Layout

```
UnrealAIPCG/                                  the UE plugin
├── UnrealAIPCG.uplugin                        descriptor; Type=Editor; Plugins: [ UnrealMCP, PCG ]
└── Source/UnrealAIPCG/
    ├── UnrealAIPCG.Build.cs                   deps: UnrealMcpRuntime + UnrealMcpEditor + PCG (+ PCG editor module)
    └── Private/
        ├── UnrealAIPCGModule.cpp              the IUnrealMcpToolProvider + module; registers the tools
        └── Tests/UnrealAIPCGSpec.cpp          UE Automation specs (one It(...) per tool)
commands/                                      bump-version / get-version / update-core / init
Tests/e2e/                                     E2E unreal-mcp-cli tool checks (one per tool)
extension.json                                 install-catalog / compatibility manifest
.github/workflows/                             CI: test_pull_request + release (+ reusable test_unreal_plugin)
```

## Develop locally

The fastest loop is a directory junction into the UE 5.7 testbed (which already has `Plugins/UnrealMCP`):

```powershell
# Junction this plugin into a UE C++ project that has Plugins/UnrealMCP available:
cmd /c mklink /J "<UEProject>\Plugins\UnrealAIPCG" "<thisRepo>\UnrealAIPCG"

# Build the editor target with UBT:
& "C:\Program Files\Epic Games\UE_5.7\Engine\Build\BatchFiles\Build.bat" `
  <UEProject>Editor Win64 Development -project="<UEProject>\<UEProject>.uproject" -WaitMutex

# Run this extension's Automation specs (filter = the module name):
& "C:\Program Files\Epic Games\UE_5.7\Engine\Binaries\Win64\UnrealEditor-Cmd.exe" `
  "<UEProject>\<UEProject>.uproject" -nullrhi -nosplash -unattended `
  -ExecCmds="Automation RunTests UnrealAIPCG; Quit" -ReportExportPath="<dir>" -log
```

Enable both plugins in the project, open the editor, and connect AI Game Developer (the Unreal-MCP
UI / sidecar); `StartupModule` registers the provider as a modular feature, so the PCG tools appear
in the tool list immediately. See the
[Unreal-MCP extension author guide](https://github.com/IvanMurzak/Unreal-MCP/blob/main/docs/EXTENSIONS.md).

## Release

Versioning is single-sourced from the `.uplugin` `VersionName`. Bump it in lock-step:

```powershell
./commands/bump-version.ps1 -NewVersion "0.2.0"   # updates .uplugin + GetExtensionVersion() + extension.json
```

Push to `main`. **`release.yml` is version-gated**: when the `VersionName` is a new value with no
existing tag, it runs the full test suite, packages the plugin **source** into a single
`UnrealAIPCG-<version>.zip`, and creates an **atomic GitHub Release** (tag `v<version>`) carrying
that one zip — the exact asset the installer downloads. The extension ships as source and UE compiles
it on the consumer's next editor open. (Track the core version floor with `./commands/update-core.ps1`.)

## CI

| Workflow | When | What |
| --- | --- | --- |
| `test_unreal_plugin.yml` | reusable | UBT build + UE Automation specs for one UE version |
| `test_pull_request.yml` | PR | the reusable test (UE 5.7) + E2E `unreal-mcp-cli` tool checks |
| `release.yml` | push to `main` | version-gated → full tests → package source zip `UnrealAIPCG-<version>.zip` → atomic GitHub Release (tag `v<version>`) |
| `bump_version.yml` | manual | runs `bump-version.ps1`, opens a release PR |

The plugin / E2E jobs run on a **self-hosted Windows UE runner** and are **never red-by-absence** —
they stay *skipped* until a runner is registered and the repo variables are set:

- `UNREAL_RUNNER_READY = true` — enables the UBT build + Automation legs.
- `UNREAL_E2E_READY = true` — enables the E2E `install-extension` + tool-invocation leg.
- `UNREAL_HOST_PROJECT` — absolute path on the runner to a host `.uproject` with UnrealMCP available.

See [`docs/claude/ci.md`](docs/claude/ci.md) and [`docs/claude/release.md`](docs/claude/release.md).

## License

[Apache-2.0](LICENSE).
