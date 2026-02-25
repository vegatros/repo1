---
name: code-review
description: Review code for best practices, security, and quality improvements
disable-model-invocation: true
---

Review the code in $ARGUMENTS for:

1. **Security**: Vulnerabilities, input validation, secrets exposure, IAM/permissions
2. **Best Practices**: Code organization, naming, DRY principles, idiomatic patterns
3. **Performance**: Inefficient patterns, unnecessary operations, resource waste
4. **Error Handling**: Missing error cases, unhandled exceptions, failure modes
5. **Correctness**: Logic bugs, race conditions, edge cases

For each finding, assign a severity (High/Medium/Low) and provide actionable fixes with specific file and line references.

End with a summary table of findings by severity.
