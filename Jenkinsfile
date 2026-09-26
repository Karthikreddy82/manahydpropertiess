pipeline {
    agent any

    environment {
        AWS_ACCOUNT_ID = '003713966273'
        AWS_REGION     = 'ap-south-1'
        ECR_REPO_NAME  = 'manahydpropertiess'
        IMAGE_TAG      = "${BUILD_NUMBER}"
        ECR_REGISTRY   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        IMAGE_URI      = "${ECR_REGISTRY}/${ECR_REPO_NAME}:${IMAGE_TAG}"
    }

    tools {
        // Must match the name configured in Manage Jenkins -> Tools
        sonarScanner 'sonar-scanner'
    }

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('SonarQube SAST Analysis') {
            steps {
                // Must match the server name configured in Manage Jenkins -> System
                withSonarQubeEnv('sonar-server') {
                    sh '''
                        sonar-scanner \
                          -Dsonar.projectKey=manahydpropertiess \
                          -Dsonar.sources=. \
                          -Dsonar.exclusions="**/*.test.js,**/node_modules/**"
                    '''
                }
            }
        }

        stage('SonarQube Quality Gate') {
            steps {
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('Trivy Source Code Scan') {
            steps {
                sh '''
                    trivy fs --exit-code 0 --severity HIGH,CRITICAL --format table .
                '''
            }
        }

        stage('Docker Build') {
            steps {
                sh """
                    docker build -t ${IMAGE_URI} -t ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest .
                """
            }
        }

        stage('Trivy Container Image Scan') {
            steps {
                sh """
                    trivy image --exit-code 0 --severity HIGH,CRITICAL --format table ${IMAGE_URI}
                """
            }
        }

        stage('Publish Image to AWS ECR') {
            steps {
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}
                    docker push ${IMAGE_URI}
                    docker push ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest
                """
            }
        }
    }

    post {
        always {
            // Prune locally tagged images to prevent build worker disk exhaustion
            sh """
                docker rmi ${IMAGE_URI} || true
                docker rmi ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest || true
            """
        }
        success {
            echo "CI/CD Pipeline executed successfully. Docker image pushed to ${IMAGE_URI}"
        }
        failure {
            echo "Pipeline failed. Inspect the console output for scan or build failures."
        }
    }
}