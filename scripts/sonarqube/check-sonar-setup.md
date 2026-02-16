# SonarCloud Setup Checklist

Exit code 3 means authentication or project configuration issue.

## Verify in SonarCloud:

1. **Project exists:**
   - Go to: https://sonarcloud.io/projects
   - Should see project: `vegatros_q`
   - If NOT, click "+ Analyze new project" and import from GitHub

2. **Token is valid:**
   - Go to: https://sonarcloud.io/account/security
   - Generate new token with name: "GitHub Actions"
   - Copy the token (starts with `squ_` or `sqp_`)

3. **Update GitHub secret:**
   - Go to: https://github.com/vegatros/q/settings/secrets/actions
   - Edit `SONAR_TOKEN` with the new token

4. **Remove SONAR_ORGANIZATION secret:**
   - It's not needed (we use sonar-project.properties)
   - Delete it if it exists

## Most likely issue:
The project `vegatros_q` doesn't exist in SonarCloud yet. Create it first!
