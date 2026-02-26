# Jenkins Pipeline Test - Manual Steps

## ✅ Jenkins is Running
- **URL**: http://10.10.1.59:8080
- **Username**: cada5000
- **Password**: REDACTED_PASSWORD

## Create and Test Pipeline

### Step 1: Login
1. Open http://10.10.1.59:8080 in your browser
2. Login with:
   - Username: `cada5000`
   - Password: `REDACTED_PASSWORD`

### Step 2: Create New Pipeline Job
1. Click "New Item" (top left)
2. Enter name: `test-pipeline`
3. Select "Pipeline"
4. Click "OK"

### Step 3: Configure Pipeline
1. Scroll down to "Pipeline" section
2. In the "Script" box, paste:

```groovy
pipeline {
    agent any
    
    stages {
        stage('Hello') {
            steps {
                echo 'Hello from Jenkins Pipeline!'
                sh 'echo "Running on: $(hostname)"'
                sh 'echo "Current user: $(whoami)"'
                sh 'date'
            }
        }
        
        stage('System Info') {
            steps {
                echo 'Gathering system information...'
                sh 'uname -a'
                sh 'df -h | head -5'
            }
        }
        
        stage('Success') {
            steps {
                echo '✅ Pipeline completed successfully!'
            }
        }
    }
    
    post {
        success {
            echo 'Build succeeded!'
        }
        failure {
            echo 'Build failed!'
        }
    }
}
```

3. Click "Save"

### Step 4: Run Pipeline
1. Click "Build Now" (left sidebar)
2. Wait for build to appear under "Build History"
3. Click on the build number (e.g., #1)
4. Click "Console Output" to see results

### Expected Output
You should see:
- ✅ Hello message
- ✅ Hostname and user info
- ✅ System information
- ✅ Success message
- ✅ "Build succeeded!" in post section

## Alternative: Use Jenkins CLI

If you prefer command line, SSH to the instance and use Jenkins CLI:

```bash
ssh -i ~/.ssh/temp_key ec2-user@10.10.1.59

# Download Jenkins CLI
wget http://localhost:8080/jnlpJars/jenkins-cli.jar

# Create job (requires API token from Jenkins UI)
java -jar jenkins-cli.jar -s http://localhost:8080/ -auth cada5000:REDACTED_PASSWORD create-job test-pipeline < job-config.xml
```

## Troubleshooting

If authentication fails:
1. Verify you completed the initial Jenkins setup wizard
2. Created the user 'cada5000' with the exact password
3. User has admin permissions
