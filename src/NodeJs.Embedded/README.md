# Embedded Node.js

NuGet package that ships prebuilt Node.js executables for Windows, Linux, and macOS (x64/arm64). It removes the requirement for a machine-level Node installation and is intended to be used together with `JavaScriptEngineSwitcher.Node` or any host that needs a portable `node` binary.

## Installing
Add the package reference:
```xml
<PackageReference Include="EmbeddedNodeJs" Version="0.1.0" />
```

Resolve the embedded executable path and pass it to your `JavaScriptEngineSwitcher.Node` settings:
```csharp
using JavaScriptEngineSwitcher.Node;
using NodeJs.Embedded;

var settings = new NodeSettings
{
    EngineExecutablePath = NodeRuntimeLocator.GetNodeExecutablePath()
};
```

## Building locally
```bash
# Fetch Node distributions into runtimes/<rid>/native/
./scripts/download-node.sh 20.12.2

# Pack
dotnet pack src/NodeJs.Embedded/NodeJs.Embedded.csproj -c Release
```

## License
The helper library is MIT licensed. Node.js binaries are provided under the Node.js license; the download script copies the upstream `LICENSE` file alongside each embedded binary.
