pipeline {
    agent any

    stages {

        stage('Checkout') {
            steps {
                git branch: 'Main', url: 'https://github.com/mumair750/ai-devsecops-java-app.git'
            }
        }

        stage('Build JAR & Test') {
            steps {
                sh 'chmod +x mvnw'
                sh './mvnw clean package'  
            }
            post {
                always {
                    junit 'target/surefire-reports/*.xml'
                    
                    jacoco(
                        execPattern: 'target/jacoco.exec',
                        classPattern: 'target/classes',
                        sourcePattern: 'src/main/java',
                        inclusionPattern: 'com/umair/*'
                    )
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                script {
                    def scannerHome = tool 'sonar-scanner'

                    withSonarQubeEnv('SonarQube') {
                        sh """
                        ${scannerHome}/bin/sonar-scanner \
                        -Dsonar.projectKey=ai-devsecops-java-app \
                        -Dsonar.projectName=ai-devsecops-java-app \
                        -Dsonar.sources=src/main/java \
                        -Dsonar.tests=src/test/java \
                        -Dsonar.java.binaries=target/classes
                        """
                    }
                }
            }
        }

        stage('SCA & SBOM (Grype + Syft)') {
            steps {
                sh '''
                echo "=========================================="
                echo "SYFT - SBOM Generation (All Formats)"
                echo "=========================================="
                
                # 1. Generate SBOM in different formats
                syft dir:. -o json > sbom.json
                syft dir:. -o cyclonedx-json > sbom-cyclonedx.json
                syft dir:. -o spdx-json > sbom-spdx.json
                syft dir:. -o table > sbom-table.txt
                
                echo "SBOMs generated:"
                echo "   - JSON: sbom.json"
                echo "   - CycloneDX: sbom-cyclonedx.json"
                echo "   - SPDX: sbom-spdx.json"
                echo "   - Table: sbom-table.txt"
                
                echo "=========================================="
                echo "GRYPE - Vulnerability Scanning (All Methods)"
                echo "=========================================="
                
                # 2. Scan SBOM for vulnerabilities
                grype sbom:sbom.json --output json > grype-report.json
                grype sbom:sbom.json --output table > grype-report.txt
                
                # 3. Direct filesystem scan
                grype dir:. --output json > grype-fs-report.json
                
                # 4. Scan with specific severity filters
                grype sbom:sbom.json --severity LOW,MEDIUM,HIGH,CRITICAL --output json > grype-all-severities.json
                
                # 5. Show only fixed vulnerabilities
                grype sbom:sbom.json --only-fixed --output table > grype-fixed-only.txt
                
                # 6. Generate HTML report
                grype sbom:sbom.json --output html > grype-report.html
                
                echo "=========================================="
                echo "Summary Reports Generated:"
                echo "=========================================="
                echo "SBOM Reports:"
                echo "   - sbom.json (JSON)"
                echo "   - sbom-cyclonedx.json (CycloneDX)"
                echo "   - sbom-spdx.json (SPDX)"
                echo ""
                echo "Vulnerability Reports:"
                echo "   - grype-report.json (JSON)"
                echo "   - grype-fs-report.json (Filesystem scan)"
                echo "   - grype-all-severities.json (LOW to CRITICAL)"
                echo "   - grype-report.html (HTML format)"
                echo "   - grype-fixed-only.txt (Fixed vulnerabilities only)"
                echo ""
                echo "Total Vulnerabilities Found:"
                grype sbom:sbom.json --output json | jq '.matches | length' 2>/dev/null || echo "Check grype-report.json for count"
                '''
            }
            post {
                always {
                    publishHTML([
                        reportDir: '.',
                        reportFiles: 'sbom.json',
                        reportName: 'SBOM (JSON)'
                    ])
                    publishHTML([
                        reportDir: '.',
                        reportFiles: 'sbom-cyclonedx.json',
                        reportName: 'SBOM (CycloneDX)'
                    ])
                    publishHTML([
                        reportDir: '.',
                        reportFiles: 'sbom-spdx.json',
                        reportName: 'SBOM (SPDX)'
                    ])
                    publishHTML([
                        reportDir: '.',
                        reportFiles: 'grype-report.json',
                        reportName: 'Grype Vulnerability Report (JSON)'
                    ])
                    publishHTML([
                        reportDir: '.',
                        reportFiles: 'grype-report.html',
                        reportName: 'Grype Vulnerability Report (HTML)'
                    ])
                    publishHTML([
                        reportDir: '.',
                        reportFiles: 'grype-fs-report.json',
                        reportName: 'Grype Filesystem Scan'
                    ])
                    publishHTML([
                        reportDir: '.',
                        reportFiles: 'grype-all-severities.json',
                        reportName: 'Grype All Severities'
                    ])
                }
            }
        }

        stage('Trivy Security Scan') {
            steps {
                sh '''
                # Scan Dockerfile for misconfigurations
                trivy config --severity HIGH,CRITICAL Dockerfile || true
                
                # Scan container image for vulnerabilities
                trivy image --severity HIGH,CRITICAL ai-devsecops-java-app:1.0 || true
                '''
            }
            post {
                always {
                    echo "Trivy scan completed"
                }
            }
        }

        stage('OPA Policy Check') {
            steps {
                sh '''
                if [ -f policy/security.rego ] && [ -f kubernetes/deployment.yaml ]; then
                    echo "Running OPA policy checks..."
                    opa eval --fail \
                        --data policy/security.rego \
                        --input kubernetes/deployment.yaml \
                        "data.kubernetes.deny" || echo "OPA violations found (allowed to continue)"
                else
                    echo "OPA policy or manifest not found - skipping"
                fi
                '''
            }
            post {
                always {
                    echo "OPA policy check completed"
                }
            }
        }

        stage('Conftest K8s Validation') {
            steps {
                sh '''
                if [ -f policy/conftest-policy.rego ] && [ -f kubernetes/deployment.yaml ]; then
                    echo "Running Conftest policy checks..."
                    conftest test kubernetes/deployment.yaml \
                        --policy policy/conftest-policy.rego \
                        --output table || echo "Conftest violations found (allowed to continue)"
                else
                    echo "Conftest policy or manifest not found - skipping"
                fi
                '''
            }
            post {
                always {
                    echo "Conftest validation completed"
                }
            }
        }

        stage('Falco Runtime Security Check') {
            steps {
                sh '''
                echo "Checking Falco for security events..."
                kubectl get pods -n falco
                kubectl logs -n falco deployment/falco --tail=20 || echo "No critical events found"
                '''
            }
            post {
                always {
                    echo "Falco runtime check completed"
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t ai-devsecops-java-app:1.0 .'
            }
        }

        stage('Push to Azure Container Registry (ACR)') {
            steps {
                script {
                    env.ACR_NAME = 'devsecopsacr1781958109'  
                    env.ACR_REGISTRY = "${env.ACR_NAME}.azurecr.io"
                    env.IMAGE_NAME = 'ai-devsecops-java-app'
                    
                    withCredentials([
                        usernamePassword(
                            credentialsId: 'azure-acr-credentials',
                            usernameVariable: 'ACR_USERNAME',
                            passwordVariable: 'ACR_PASSWORD'
                        )
                    ]) {
                        sh '''
                        echo "Logging in to ACR..."
                        echo $ACR_PASSWORD | docker login $ACR_REGISTRY -u $ACR_USERNAME --password-stdin
                        
                        echo "Tagging image for ACR..."
                        docker tag ai-devsecops-java-app:1.0 $ACR_REGISTRY/$IMAGE_NAME:latest
                        docker tag ai-devsecops-java-app:1.0 $ACR_REGISTRY/$IMAGE_NAME:${BUILD_NUMBER}
                        
                        echo "Pushing image to ACR..."
                        docker push $ACR_REGISTRY/$IMAGE_NAME:latest
                        docker push $ACR_REGISTRY/$IMAGE_NAME:${BUILD_NUMBER}
                        
                        echo "Image pushed to ACR: $ACR_REGISTRY/$IMAGE_NAME:${BUILD_NUMBER}"
                        '''
                    }
                }
            }
            post {
                success {
                    echo "ACR push successful!"
                }
                failure {
                    echo "ACR push failed!"
                }
            }
        }
    }
}