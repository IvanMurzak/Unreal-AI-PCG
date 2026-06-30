# E2E tool check (one-test-per-tool). Copy this file per tool your extension contributes.
# Returned to Run-ToolChecks.ps1, which invokes `unreal-mcp-cli run-tool <Tool>` against the
# running project's MCP server and asserts a well-formed success.
@{
    Tool   = "hello-extension"
    System = $false
    Input  = '{"name":"CI"}'
    Assert = {
        param($Result)
        # The sample tool returns a structured result carrying a "greeting" field. Assert it is
        # present (a well-formed success). Adjust to your tool's real result shape.
        $serialized = $Result | ConvertTo-Json -Depth 20 -Compress
        if ($serialized -notmatch 'greeting') {
            throw "expected a 'greeting' field in the tool result; got: $serialized"
        }
    }
}
