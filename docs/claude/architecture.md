# Architecture — an Unreal-MCP extension

## The single extension shape

Every Unreal-MCP extension is a **C++ `Type=Editor` UE plugin** that:

1. **Implements `IUnrealMcpToolProvider`** and registers its tools via the fluent
   `FUnrealMcpToolRegistry` builder. The contract lives in the Unreal-MCP plugin's **runtime** module
   (`UnrealMcpRuntime/Public/IUnrealMcpToolProvider.h` + `UnrealMcpToolRegistry.h`); `UnrealMcpEditor`
   re-exports those headers and adds editor-only API access.
2. **Registers the provider as a modular feature** in `StartupModule`
   (`IModularFeatures::Get().RegisterModularFeature(IUnrealMcpToolProvider::GetModularFeatureName(), Provider)`)
   and unregisters it in `ShutdownModule`. Unreal-MCP discovers it on boot via initial enumeration,
   and live via the `OnModularFeatureRegistered` event when the plugin loads later. Unregister →
   registry rebuild + manifest revision bump → the tools disappear from the advertised set.
3. **Depends on the feature it wraps.** The `*.Build.cs` lists `UnrealMcpRuntime` + `UnrealMcpEditor`
   (the contract/registry) **and** the feature's engine modules (e.g. `Niagara`, `NiagaraEditor`); the
   `.uplugin` lists `Plugins: [ { UnrealMCP }, { Niagara } ]`. That dependency **is the gating** — the
   extension won't compile or load without the engine plugin it targets.

The only real gradient is **handler weight**: *thin* (lambdas over game-thread-safe feature APIs —
most cases) vs *thick* (needs async / subsystems / own UI). Both are C++ editor plugins.

**Enablement policy: default OFF / opt-in.** An extension is a real dependency with build + cook +
context cost, so users enable only what a task needs.

## Files in this template

| Path | What |
| --- | --- |
| `YOUR_EXTENSION_MODULE/YOUR_EXTENSION_MODULE.uplugin` | Descriptor. `VersionName` = the version single source. `Plugins` lists the core + gating engine plugin. Module is `Type=Editor`. |
| `.../Source/YOUR_EXTENSION_MODULE/YOUR_EXTENSION_MODULE.Build.cs` | Module rules. Deps: `UnrealMcpRuntime` + `UnrealMcpEditor` (required) + your feature modules (commented placeholder). |
| `.../Private/YOUR_EXTENSION_MODULEModule.cpp` | The provider (`GetExtensionId/DisplayName/Version`, `RegisterTools`) + the editor module that registers it. One sample tool. |
| `.../Private/Tests/YOUR_EXTENSION_MODULESpec.cpp` | Sample UE Automation spec (guarded by `WITH_DEV_AUTOMATION_TESTS`). One `It(...)` per tool. |
| `Tests/e2e/` | E2E `unreal-mcp-cli` tool checks (one per tool) + the `Run-ToolChecks.ps1` harness. |
| `extension.json` | Install-catalog / compatibility manifest: `version` (mirrors `.uplugin`), `minCoreVersion`. |
| `commands/` | `init` (PowerShell + Python), `bump-version`, `get-version`, `update-core`. |

## init flow

`commands/init.ps1` / `commands/init.py`:
1. Replaces placeholder tokens in file **content** across the tree (excluding `commands/`, VCS, and
   build artifacts).
2. Renames files/folders containing `YOUR_EXTENSION_MODULE` (deepest-first).
3. If `-FeaturePlugin` is given, inserts it into the `.uplugin` `Plugins` array and uncomments the
   feature-module dependencies in the `*.Build.cs`.
4. Activates the `*.yml-sample` workflows.

The `bump-version` / `get-version` / `update-core` scripts **discover** the `.uplugin` at runtime
(glob), so they keep working after the rename without being placeholder-substituted — that is why
`init` excludes `commands/`.

## Test module note

For simplicity the sample Automation spec lives **inside the extension module**, guarded by
`#if WITH_DEV_AUTOMATION_TESTS` (which is `1` in Development editor builds). A production extension
that ships to Fab may prefer to split the specs into a separate `*Tests` editor module (as the
Unreal-MCP core does) so the distributed package carries no test code — see the core repo's
`UnrealMcpEditorTests` module for that pattern.
