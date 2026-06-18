pipeline {
    agent any

    stages {
        stage('Checkout') {
            steps {
                git branch: 'Main', url: 'https://github.com/mumair750/ai-devsecops-java-app.git'
            }
        }

        stage('Build JAR') {
            steps {
                sh 'chmod +x mvnw'
                sh './mvnw clean package'
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

        stage('Build Docker Image') {
            steps {
                sh 'docker build -t ai-devsecops-java-app:1.0 .'
            }
        }
    }
}