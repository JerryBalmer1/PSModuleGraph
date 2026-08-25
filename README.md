# PSModuleAst

Static inspection of PowerShell modules through the AST. Nothing is imported,
dot-sourced, or executed — every result traces back to a file and a line number.

> Repository: [PS.Module.Dependency.Analyzer](https://github.com/JerryBalmer1/PS.Module.Dependency.Analyzer)

## Quick start

```powershell
git clone https://github.com/JerryBalmer1/PS.Module.Dependency.Analyzer.git
cd PS.Module.Dependency.Analyzer
./build.ps1 -Bootstrap          # installs InvokeBuild, Pester 6.1.0, PSScriptAnalyzer
./build.ps1                     # Clean, Lint, Build, Test
./build.ps1 -Task Import        # load the built module into the current session
```

## Commands

| Command | Returns |
| --- | --- |
| `Get-PSModuleFunction` | Functions and filters, with export status resolved from the manifest |
| `Get-PSModuleClass` | Classes, base types, interfaces, DSC attribution |
| `Get-PSModuleEnum` | Enums with labels and underlying values |
| `Get-PSModuleManifest` | Parsed `.psd1` surface and declared dependencies |
| `Get-PSModuleSourceFile` | Every `.ps1`/`.psm1`/`.psd1` in the module, with parse status |
| `Get-PSModuleAssembly` | `RequiredAssemblies`, binary `NestedModules`, `Add-Type` sites, loose `.dll`s |
| `Get-PSModuleUsingStatement` | `using module` / `namespace` / `assembly` |
| `Get-PSModuleCommandReference` | Raw call sites attributed to the enclosing function |
| `Get-PSModuleDependencyGraph` | Node/edge model with roots, leaves, unresolved targets |
| `Export-PSModuleDependencyGraph` | JSON, Graphviz DOT, Mermaid, or CSV edge list |

## Parameter sets

Every command accepts the same three:

```powershell
Get-PSModuleFunction -Name PSReadLine                    # loaded first, then PSModulePath
Get-PSModuleFunction -Name PSReadLine -RequiredVersion 2.3.4
Get-PSModuleFunction -Path ./src/PSModuleAst             # dir, .psd1, or .psm1
Get-Module PSReadLine | Get-PSModuleFunction             # PSModuleInfo from the pipeline
```

## Graph output

```powershell
Get-PSModuleDependencyGraph -Path ./src/PSModuleAst |
    Export-PSModuleDependencyGraph -Format Dot -OutputPath ./output/graph.dot
dot -Tsvg ./output/graph.dot -o graph.svg
```

`Roots` are nodes with no inbound internal edge — entry points, or dead code.
`Unresolved` holds call targets that are not defined inside the module; they are
surfaced rather than silently dropped, because the interesting bugs live there.

## Requirements

- Windows PowerShell 5.1 or PowerShell 7.4+ (Pester 6 dropped everything else)
- Build-time: InvokeBuild, Pester 6.1.0, PSScriptAnalyzer

## License

MIT
