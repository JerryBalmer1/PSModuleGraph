I'm creating a new module: PS.Module.Dependency.Analyzer

https://github.com/JerryBalmer1/PS.Module.Dependency.Analyzer.git


Functions needed (that I know of right now. also, if you can come up with better names, do it) :
* Get-PSModuleEnums
* Get-PSModuleClasses
* Get-PSModuleFunctions
* Get-PSModuleManifest
* Get-PSModuleScriptFile
* Get-PSModuleDependencyGraph
  - Get's the "links" between each type, finds "root" objects, and builds things in a way the it should be able to build a graph from it, that any graphing tool can leverage.
  - It should use a file path to retieve the ast, so that we can also get the file path, as well.
  - there should be a minimum of 2 parametersets:
    - One should take a module name.
      - (figure out if I'm missing something here...)
      - If it's in memory, get the modules depenency information.
    - One should use a Path parameter (think of src/module)
(I might be forgetting some here, like for .dll's, etc...)


Have the agent scaffold (claude) a standard powershell module repository:
- InvokeBuild, Pester 6.1.X, etc.

Do you need anything else to create a good CLAUDE.md ?


