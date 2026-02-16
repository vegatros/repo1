#!/bin/bash
# Local SonarQube test script

echo "Starting local SonarQube server..."
docker run -d --name sonarqube -p 9000:9000 sonarqube:community

echo "Waiting for SonarQube to start (60s)..."
sleep 60

echo "SonarQube available at: http://localhost:9000"
echo "Default credentials: admin/admin"
echo ""
echo "To scan locally, install sonar-scanner:"
echo "  brew install sonar-scanner  # macOS"
echo "  apt install sonar-scanner   # Ubuntu"
echo ""
echo "Then run: sonar-scanner -Dsonar.host.url=http://localhost:9000 -Dsonar.login=<token>"
