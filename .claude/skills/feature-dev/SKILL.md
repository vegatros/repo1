---
name: feature-dev
description: Create a feature branch and scaffold files for a new feature
disable-model-invocation: true
---

Create a new feature branch and scaffold the necessary files based on the description: $ARGUMENTS

Steps:
1. Create a new git branch named `feature/<short-kebab-case-name>` from the current branch
2. Identify the appropriate directory and existing patterns in the codebase
3. Scaffold the required files following existing project conventions (file structure, naming, config patterns)
4. Include boilerplate code that matches the project's style and standards
5. Stage the new files with git add
6. Provide a summary of what was created and suggested next steps
