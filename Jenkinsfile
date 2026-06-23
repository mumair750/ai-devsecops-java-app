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
                
                syft dir:. -o json > sbom.json || true
                syft dir:. -o cyclonedx-json > sbom-cyclonedx.json || true
                syft dir:. -o spdx-json > sbom-spdx.json || true
                syft dir:. -o table > sbom-table.txt || true
                
                echo "=========================================="
                echo "GRYPE - Vulnerability Scanning"
                echo "=========================================="
                
                grype sbom:sbom.json --output json > grype-report.json || true
                grype sbom:sbom.json --output table > grype-report.txt || true
                grype dir:. --output json > grype-fs-report.json || true
                grype sbom:sbom.json --only-fixed --output table > grype-fixed-only.txt || true

                {
                    echo "<html><head><title>Grype Vulnerability Report</title></head><body>"
                    echo "<h1>Grype Vulnerability Report</h1><pre>"
                    grype sbom:sbom.json --output table
                    echo "</pre></body></html>"
                } > grype-report.html || true
                
                echo "Reports generated successfully!"
                '''
            }
            post {
                always {
                    publishHTML([
                        reportDir: '.',
                        reportFiles: 'sbom.json',
                        reportName: 'SBOM (JSON)',
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true
                    ])
                    publishHTML([
                        reportDir: '.',
                        reportFiles: 'sbom-cyclonedx.json',
                        reportName: 'SBOM (CycloneDX)',
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true
                    ])
                    publishHTML([
                        reportDir: '.',
                        reportFiles: 'sbom-spdx.json',
                        reportName: 'SBOM (SPDX)',
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true
                    ])
                    publishHTML([
                        reportDir: '.',
                        reportFiles: 'grype-report.json',
                        reportName: 'Grype Report (JSON)',
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true
                    ])
                    publishHTML([
                        reportDir: '.',
                        reportFiles: 'grype-report.html',
                        reportName: 'Grype Report (HTML)',
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true
                    ])
                    publishHTML([
                        reportDir: '.',
                        reportFiles: 'grype-fs-report.json',
                        reportName: 'Grype Filesystem Scan',
                        allowMissing: true,
                        alwaysLinkToLastBuild: true,
                        keepAll: true
                    ])
                }
            }
        }

        stage('Trivy Security Scan') {
            steps {
                sh '''
                # Scan Dockerfile for misconfigurations
                trivy config --severity HIGH,CRITICAL Dockerfile || true
                
                # Scan container image with timeout
                trivy image --severity HIGH,CRITICAL --timeout 15m ai-devsecops-java-app:1.0 || true
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
                withCredentials([
                    file(credentialsId: 'kubeconfig-file', variable: 'KUBECONFIG')
                ]) {
                    sh '''
                    echo "=========================================="
                    echo "Falco Runtime Security Check"
                    echo "=========================================="

                    export KUBECONFIG=$KUBECONFIG

                    echo "--- Falco Pod Status ---"
                    kubectl get pods -n falco \
                        --request-timeout=15s

                    echo "--- Falco Security Events (last 50 lines) ---"
                    kubectl logs -n falco \
                        -l app.kubernetes.io/name=falco \
                        --tail=50 \
                        --request-timeout=20s 2>/dev/null \
                        | grep -E "(Warning|Critical|Emergency|Error)" \
                        | head -30 \
                        || echo "No critical Falco security events found"

                    echo "--- Pod Details ---"
                    kubectl get pods -n falco -o wide \
                        --request-timeout=10s

                    echo "=========================================="
                    echo "Falco check completed successfully"
                    echo "=========================================="
                    '''
                }
            }
            post {
                always { echo "Falco runtime check completed" }
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

    post {
        success {
            sh '''
            curl -X POST -H 'Content-type: application/json' \
                --data '{"text":"*PIPELINE SUCCESSFUL!*\\n• Job: '${JOB_NAME}'\\n• Build: #'${BUILD_NUMBER}'\\n• Image Tag: '${BUILD_NUMBER}'\\n• Deployed to: AKS Green\\n• URL: '${BUILD_URL}'"}' \
                'https://hooks.slack.com/services/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'
            '''
        }
        failure {
            sh '''
            curl -X POST -H 'Content-type: application/json' \
                --data '{"text":"*PIPELINE FAILED!*\\n• Job: '${JOB_NAME}'\\n• Build: #'${BUILD_NUMBER}'\\n• Stage: '${STAGE_NAME}'\\n• URL: '${BUILD_URL}'"}' \
                'https://hooks.slack.com/services/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'
            '''
        }
    }
}