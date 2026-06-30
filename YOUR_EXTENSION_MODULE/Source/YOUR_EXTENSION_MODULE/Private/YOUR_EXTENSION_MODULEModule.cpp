// Copyright (c) 2026 YOUR_GITHUB_USERNAME_REPOSITORY. Licensed under the Apache License, Version 2.0.
// See the LICENSE file in the repository root for more information.

#include "Modules/ModuleManager.h"
#include "Features/IModularFeatures.h"

#include "IUnrealMcpToolProvider.h"
#include "UnrealMcpToolRegistry.h"

DEFINE_LOG_CATEGORY_STATIC(LogYOUR_EXTENSION_MODULE, Log, All);

/**
 * The extension's tool provider — an implementation of the Unreal-MCP extension contract
 * (IUnrealMcpToolProvider). It declares this extension's tools through the fluent
 * FUnrealMcpToolRegistry builder. See https://github.com/IvanMurzak/Unreal-MCP/blob/main/docs/EXTENSIONS.md.
 *
 * Keep GetExtensionVersion() in sync with the .uplugin VersionName — `commands/bump-version.ps1`
 * updates both atomically.
 */
class FYOUR_EXTENSION_MODULEProvider : public IUnrealMcpToolProvider
{
public:
	virtual FString GetExtensionId() const override { return TEXT("YOUR_EXTENSION_ID"); }
	virtual FText GetDisplayName() const override { return NSLOCTEXT("YOUR_EXTENSION_MODULE", "DisplayName", "YOUR_EXTENSION_DISPLAY_NAME"); }
	virtual FString GetExtensionVersion() const override { return TEXT("0.1.0"); }

	virtual void RegisterTools(FUnrealMcpToolRegistry& Registry) override
	{
		// =====================================================================================
		//  ADD YOUR TOOLS HERE
		// =====================================================================================
		// Declare each tool with the fluent builder. Tool ids MUST be kebab-case
		// (^[a-z0-9]+(-[a-z0-9]+)*$). The handler runs ON the game thread (the dispatcher
		// guarantees it), so you may call editor / engine APIs directly. Return
		// FUnrealMcpToolResult::Success(text, structuredJson) or ::Error(message).
		//
		// One sample tool ("YOUR_TOOL_ID") ships so the extension is end-to-end functional
		// out of the box. Replace it with your feature's real tools.
		Registry.Tool(TEXT("YOUR_TOOL_ID"))
			.Title(TEXT("YOUR_EXTENSION_DISPLAY_NAME — sample tool"))
			.Description(TEXT("Sample tool proving the IUnrealMcpToolProvider contract end-to-end. "
			                  "Returns a friendly greeting, optionally addressed to 'name'. Replace with your own."))
			.ParamString(TEXT("name"), TEXT("Who to greet. Defaults to 'world'."))
			.ReadOnlyHint(true)
			.IdempotentHint(true)
			.Handle([](const FUnrealMcpToolCall& Call) -> FUnrealMcpToolResult
			{
				const FString Name = Call.Has(TEXT("name")) ? Call.GetString(TEXT("name")) : TEXT("world");
				const FString Greeting = FString::Printf(TEXT("Hello, %s! — from the YOUR_EXTENSION_DISPLAY_NAME extension."), *Name);

				TSharedPtr<FJsonObject> Structured = MakeShared<FJsonObject>();
				Structured->SetStringField(TEXT("greeting"), Greeting);
				return FUnrealMcpToolResult::Success(Greeting, Structured);
			});
	}
};

/**
 * Editor module that owns the provider and registers it as a modular feature, so Unreal-MCP discovers
 * it — on boot via initial enumeration, or live via the OnModularFeatureRegistered event when this
 * plugin loads after Unreal-MCP. Unregistering on shutdown triggers a registry rebuild + manifest
 * revision bump on the Unreal-MCP side (the token-economy win: disabling the extension live-removes
 * its tools from the advertised set).
 */
class FYOUR_EXTENSION_MODULEModule : public IModuleInterface
{
public:
	virtual void StartupModule() override
	{
		Provider = MakeUnique<FYOUR_EXTENSION_MODULEProvider>();
		IModularFeatures::Get().RegisterModularFeature(IUnrealMcpToolProvider::GetModularFeatureName(), Provider.Get());
		UE_LOG(LogYOUR_EXTENSION_MODULE, Log, TEXT("[YOUR_EXTENSION_MODULE] registered MCP tool provider '%s'."), *Provider->GetExtensionId());
	}

	virtual void ShutdownModule() override
	{
		if (Provider.IsValid())
		{
			IModularFeatures::Get().UnregisterModularFeature(IUnrealMcpToolProvider::GetModularFeatureName(), Provider.Get());
			Provider.Reset();
			UE_LOG(LogYOUR_EXTENSION_MODULE, Log, TEXT("[YOUR_EXTENSION_MODULE] unregistered MCP tool provider."));
		}
	}

private:
	TUniquePtr<FYOUR_EXTENSION_MODULEProvider> Provider;
};

IMPLEMENT_MODULE(FYOUR_EXTENSION_MODULEModule, YOUR_EXTENSION_MODULE)
