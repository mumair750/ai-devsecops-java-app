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

        stage('OWASP Dependency Check') {
            steps {
                withCredentials([string(credentialsId: 'nvd-api-key', variable: 'NVD_API_KEY')]) {
                    sh '''
                    ./mvnw org.owasp:dependency-check-maven:check \
                        -DnvdApiKey=${NVD_API_KEY} \
                        -Dformat=HTML \
                        -DoutputDirectory=target/dependency-check-report \
                        -DdataDirectory=/var/jenkins_home/.dependency-check \
                        -DnvdValidForHours=720 \
                        -DskipUpdate=true \
                        -DfailOnError=false
                    '''
                }
            }
            post {
                always {
                    script {
                        if (fileExists('target/dependency-check-report/dependency-check-report.html')) {
                            publishHTML([
                                reportDir: 'target/dependency-check-report',
                                reportFiles: 'dependency-check-report.html',
                                reportName: 'OWASP Security Report'
                            ])
                        } else {
                            echo "OWASP report not generated - skipping publish"
                        }
                    }
                }
                failure {
                    echo "OWASP Scan failed but continuing pipeline..."
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