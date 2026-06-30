# Unreal-AI-PCG

This is the **Unreal AI PCG** extension — a C++ `Type=Editor` Unreal Engine plugin that implements
the Unreal-MCP contract `IUnrealMcpToolProvider` and contributes a family of MCP tools wrapping the
engine's built-in **PCG (Procedural Content Generation)** plugin to AI Game Developer (Unreal-MCP).
It was scaffolded from `IvanMurzak/Unreal-AI-Template`; the plugin/module is `UnrealAIPCG` (UE module
names can't contain `-`, so the repo's `Unreal-AI-PCG` becomes `UnrealAIPCG`).

The dependency on the `PCG` engine plugin (a `.Build.cs` module dep + a `.uplugin` `Plugins[]` entry)
**is the gating**: this extension won't compile or load unless PCG is present in the host project.

## The tools

The provider (`FUnrealAIPCGProvider` in `UnrealAIPCG/Source/UnrealAIPCG/Private/UnrealAIPCGModule.cpp`)
registers PCG tools via the fluent `Registry.Tool(...).Handle(...)` builder:

- `pcg-list-graphs` — list every PCG graph asset (Asset Registry, read-only).
- `pcg-get-graph` — inspect a single PCG graph asset (read-only).
- `pcg-add-component` — add a `UPCGComponent` to an actor in the editor world.
- `pcg-get-component` — inspect an actor's PCG component (read-only).
- `pcg-generate` — trigger generation / refresh on an actor's PCG component.

The exact set is settled during implementation; `extension.json` `tools[]` + the README table are the
source of truth, and each tool ships one UE Automation spec + one E2E check. Handlers run on the
**game thread** and call PCG / editor APIs directly; mutating tools validate engine state defensively
(UE has no C++ exceptions — a crash in a handler is an editor crash) and return
`FUnrealMcpToolResult::Error(...)`, never an unchecked deref.

## The contract (read before editing tools)

- `IUnrealMcpToolProvider` (in Unreal-MCP `UnrealMcpRuntime/Public/IUnrealMcpToolProvider.h`):
  `GetExtensionId()` / `GetDisplayName()` / `GetExtensionVersion()` / `RegisterTools(FUnrealMcpToolRegistry&)`.
- Tools are declared with the fluent builder: `Registry.Tool("kebab-id").Title(...).Param*(...).Handle([](const FUnrealMcpToolCall&){...})`.
- The provider is registered as a **modular feature** in `StartupModule` and unregistered in
  `ShutdownModule`. Unreal-MCP discovers it on boot or live.
- Handlers run on the **game thread** (call editor/engine APIs directly). Tool ids MUST match
  `^[a-z0-9]+(-[a-z0-9]+)*$` or the registry drops them. Do NOT call `.ExtensionId(...)` — it's stamped.

## Commands

```powershell
./commands/bump-version.ps1 -NewVersion "0.2.0"   # .uplugin VersionName + GetExtensionVersion() + extension.json
./commands/get-version.ps1                        # prints the .uplugin VersionName (single source of truth)
./commands/update-core.ps1                        # refreshes extension.json minCoreVersion from Unreal-MCP releases
```

## Build / test (local loop)

Junction `UnrealAIPCG/` into a UE 5.7 project that has the UnrealMCP core plugin available (the
`engines/unreal/test-project` testbed already junctions `Plugins/UnrealMCP`), then build the editor
target with UBT and run the Automation specs with filter = the module name (`UnrealAIPCG`). See
`README.md` → "Develop locally". CI does the same on a self-hosted Windows UE runner.

## Conventions

- **Naming:** repo `Unreal-AI-PCG` (hyphens); plugin + module `UnrealAIPCG` (no hyphens — UE module
  names can't contain `-`); C++ prefixes `F*`/`U*`/`I*`; tool ids kebab-case `pcg-<op>`.
- **C++ style:** Unreal — tabs, braces on new lines, UE types. File header: the
  `// Copyright (c) 2026 ...` Apache-2.0 one-liner. The module is **unity-built** (every `.cpp` is
  concatenated into one TU), so give file-local helpers a module-unique name (prefix `UnrealAIPCG_`) —
  an `anonymous namespace` does NOT make a helper file-private here.
- **Versioning:** the `.uplugin` `VersionName` is the single source of truth; never hand-edit one
  version location alone — use `bump-version.ps1`. Keep `GetExtensionVersion()` == the `VersionName`.
- **Tests:** one UE Automation spec + one E2E `unreal-mcp-cli` check **per tool**.
- **Distribution:** GitHub-Release source zip `UnrealAIPCG-<version>.zip` at tag `v<version>`; UE
  compiles on the consumer's next editor open. NOT a NuGet package, NOT precompiled binaries.
- **Secrets:** never commit `.env` or tokens.

## Find detail in

- `README.md` — the user-facing tools / install / develop / release / CI walkthrough.
- `docs/claude/architecture.md` — extension shape, the contract, layout.
- `docs/claude/ci.md` — workflows, required repo variables, self-hosted runner gating.
- `docs/claude/release.md` — version gate + atomic release mechanics.
