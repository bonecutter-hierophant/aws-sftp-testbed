# Diagram Rendering

Date: 2026-06-16

This repository follows the SimpleETL PlantUML workflow: `.puml` source files are committed beside the docs or code they describe, and diagrams are previewed locally through VS Code.

## Required Local Tooling

Install:

- Java SDK
- Graphviz
- VS Code PlantUML extension: `jebbs.plantuml`

On Windows, Graphviz is expected at:

```text
C:\Program Files\Graphviz\bin\dot.exe
```

The repo-level VS Code settings use local PlantUML rendering and pass that Graphviz path to PlantUML.

SimpleETL also points VS Code at the PlantUML extension's bundled jar through a machine-local User setting. Keep that user-profile path out of this public repository. If VS Code does not automatically find the extension jar, set `plantuml.jar` in VS Code User settings rather than committing a machine-local path here.

## VS Code Setup

Open the repository in VS Code and install the recommended extensions when prompted:

- AWS Toolkit
- PlantUML
- YAML

Then open any `.puml` file and use the PlantUML preview command from the editor.

The durable setup is machine-level tooling plus repo-level editor settings. Avoid generated branch-local PlantUML dependencies; they are easy to lose or break when switching branches.

## Notes

- Do not commit rendered diagram output by default.
- Keep `.puml` files small and local to the responsibility they describe.
- Update the local README and `.puml` file together when ownership, dependencies, lifecycle, or public behavior changes.
