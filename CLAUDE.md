# Unreal-AI-Template

This is the **template repo** for authoring new **Unreal-MCP extension** plugins (the Unreal analog
of `Unity-AI-Tools-Template`). An extension is a C++ `Type=Editor` UE plugin implementing
`IUnrealMcpToolProvider` that contributes MCP tools to AI Game Developer (Unreal-MCP).

Boilerplate is customized by `commands/init.ps1` (or `commands/init.py`), which renames the
plugin/module and replaces placeholders (`YOUR_EXTENSION_MODULE`, `YOUR_EXTENSION_ID`,
`YOUR_EXTENSION_DISPLAY_NAME`, `YOUR_TOOL_ID`, `YOUR_GITHUB_USERNAME_REPOSITORY`,
`YOUR_FEATURE_PLUGIN`/`YOUR_FEATURE_MODULE`). Changes here propagate to every future extension —
keep placeholder tokens consistent.

## The contract (DO read before editing tools)

- `IUnrealMcpToolProvider` (in Unreal-MCP `UnrealMcpRuntime/Public/IUnrealMcpToolProvider.h`):
  `GetExtensionId()` / `GetDisplayName()` / `GetExtensionVersion()` / `RegisterTools(FUnrealMcpToolRegistry&)`.
- Tools are declared with the fluent builder: `Registry.Tool("kebab-id").Title(...).Param*(...).Handle([](const FUnrealMcpToolCall&){...})`.
- The provider is registered as a **modular feature** in `StartupModule` and unregistered in
  `ShutdownModule`. Unreal-MCP discovers it on boot or live.
- Handlers run on the **game thread** (call editor/engine APIs directly). Tool ids MUST match
  `^[a-z0-9]+(-[a-z0-9]+)*$` or the registry drops them.

## Commands

```powershell
# Scaffold a new extension from the template
./commands/init.ps1 -ExtensionModule "UnrealAINiagara" -ExtensionId "com.company.unreal-ai-niagara" `
  -DisplayName "Unreal AI Niagara" -GitHubRepository "Owner/Unreal-AI-Niagara" -FeaturePlugin "Niagara"
# (cross-platform parity: python commands/init.py --module ... --id ... --name ... --repo ... --feature ...)

./commands/bump-version.ps1 -NewVersion "0.2.0"   # .uplugin VersionName + GetExtensionVersion() + extension.json
./commands/get-version.ps1                        # prints the .uplugin VersionName (single source of truth)
./commands/update-core.ps1                        # refreshes extension.json minCoreVersion from Unreal-MCP releases
```

## Build / test (local loop)

Junction the plugin into a UE project that has the UnrealMCP core plugin available, then build with
UBT (see `README.md` step 4). Run Automation specs with filter = the module name. CI does the same
on a self-hosted runner.

## Conventions

- **Naming:** repo `Unreal-AI-<Feature>` (hyphens); plugin + module `UnrealAI<Feature>` (no hyphens —
  UE module names can't contain `-`); C++ prefixes `F*`/`U*`/`I*`; tool ids kebab-case.
- **C++ style:** Unreal — tabs, braces on new lines, UE types. File header: the
  `// Copyright (c) 2026 ...` Apache-2.0 one-liner.
- **Versioning:** the `.uplugin` `VersionName` is the single source of truth; never hand-edit one
  version location alone — use `bump-version.ps1`.
- **Tests:** one UE Automation spec + one E2E `unreal-mcp-cli` check **per tool**.
- **Secrets:** never commit `.env` or tokens.

## Find detail in

- `README.md` — the full user-facing scaffold → init → build → register → release → install walkthrough.
- `docs/claude/architecture.md` — extension shape, the contract, init flow, layout.
- `docs/claude/ci.md` — workflows, required repo variables, self-hosted runner gating.
- `docs/claude/release.md` — version gate + atomic release mechanics.
