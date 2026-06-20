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

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t ai-devsecops-java-app:1.0 .'
            }
        }

        stage('Push Docker Image') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    sh '''
                    docker login -u $DOCKER_USER -p $DOCKER_PASS

                    docker tag ai-devsecops-java-app:1.0 mumairask750/ai-devsecops-java-app:latest

                    docker push mumairask750/ai-devsecops-java-app:latest
                    '''
                }
            }
        }
    }
}