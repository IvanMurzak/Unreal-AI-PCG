// Copyright (c) 2026 YOUR_GITHUB_USERNAME_REPOSITORY. Licensed under the Apache License, Version 2.0.
// See the LICENSE file in the repository root for more information.

#if WITH_DEV_AUTOMATION_TESTS

#include "CoreMinimal.h"
#include "Misc/AutomationTest.h"
#include "Features/IModularFeatures.h"

#include "IUnrealMcpToolProvider.h"
#include "UnrealMcpToolRegistry.h"

// ============================================================================================
//  SAMPLE UE Automation spec — ONE-TEST-PER-TOOL convention.
//
//  Every tool your extension contributes gets a focused Automation spec asserting it
//  (a) registers under its kebab-case id and (b) returns a well-formed result. This sample
//  covers the shipped `YOUR_TOOL_ID` tool. Copy the `It(...)` block per new tool.
//
//  The spec discovers THIS extension's live provider through IModularFeatures (the exact path
//  Unreal-MCP uses), registers its tools into a throwaway registry, and exercises them — so it
//  validates the real shipped provider, not a stand-in.
//
//  Run via:  Automation RunTests YOUR_EXTENSION_MODULE
// ============================================================================================

namespace
{
	// Spec-unique helper name (the module is unity-built — keep file-local helpers uniquely named).
	IUnrealMcpToolProvider* YOUR_EXTENSION_MODULE_FindOwnProvider()
	{
		const TArray<IUnrealMcpToolProvider*> Providers =
			IModularFeatures::Get().GetModularFeatureImplementations<IUnrealMcpToolProvider>(
				IUnrealMcpToolProvider::GetModularFeatureName());
		for (IUnrealMcpToolProvider* Provider : Providers)
		{
			if (Provider && Provider->GetExtensionId() == TEXT("YOUR_EXTENSION_ID"))
			{
				return Provider;
			}
		}
		return nullptr;
	}
}

BEGIN_DEFINE_SPEC(FYOUR_EXTENSION_MODULESpec, "YOUR_EXTENSION_MODULE",
	EAutomationTestFlags::EditorContext | EAutomationTestFlags::ProductFilter)
END_DEFINE_SPEC(FYOUR_EXTENSION_MODULESpec)

void FYOUR_EXTENSION_MODULESpec::Define()
{
	Describe("provider registration", [this]()
	{
		It("registers this extension as a modular-feature tool provider", [this]()
		{
			IUnrealMcpToolProvider* Provider = YOUR_EXTENSION_MODULE_FindOwnProvider();
			TestNotNull(TEXT("extension provider is registered as a modular feature"), Provider);
			if (Provider)
			{
				TestEqual(TEXT("extension id matches the descriptor"),
					Provider->GetExtensionId(), FString(TEXT("YOUR_EXTENSION_ID")));
			}
		});
	});

	Describe("tool: YOUR_TOOL_ID", [this]()
	{
		It("registers under its kebab-case id and returns a well-formed success", [this]()
		{
			IUnrealMcpToolProvider* Provider = YOUR_EXTENSION_MODULE_FindOwnProvider();
			if (!Provider)
			{
				AddError(TEXT("extension provider not registered — cannot exercise its tools"));
				return;
			}

			FUnrealMcpToolRegistry Registry;
			Registry.RegisterExtension(Provider->GetExtensionId(),
				[Provider](FUnrealMcpToolRegistry& R) { Provider->RegisterTools(R); });

			TestTrue(TEXT("YOUR_TOOL_ID is registered"), Registry.HasTool(TEXT("YOUR_TOOL_ID")));

			// Invoke with an argument and assert the structured result is well-formed.
			TSharedPtr<FJsonObject> Args = MakeShared<FJsonObject>();
			Args->SetStringField(TEXT("name"), TEXT("Automation"));
			const FUnrealMcpToolResult Result = Registry.Execute(TEXT("YOUR_TOOL_ID"), FUnrealMcpToolCall(Args));

			TestTrue(TEXT("tool reports success"), Result.bSuccess);
			TestFalse(TEXT("tool returned a non-empty message"), Result.Message.IsEmpty());
			TestTrue(TEXT("structured result carries a 'greeting' field"),
				Result.Structured.IsValid() && Result.Structured->HasField(TEXT("greeting")));
		});
	});
}

#endif // WITH_DEV_AUTOMATION_TESTS
