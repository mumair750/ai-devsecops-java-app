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
                sh './mvnw org.owasp:dependency-check-maven:check'
            }
             post {
                always {
                    publishHTML([
                    reportDir: 'target/dependency-check-report',
                    reportFiles: 'dependency-check-report.html',
                    reportName: 'OWASP Dependency Check Report'
            ])
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