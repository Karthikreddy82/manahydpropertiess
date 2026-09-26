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

    stages {
        stage('Checkout Code') {
            steps {
                checkout scm
            }
        }

        stage('SonarQube SAST Analysis') {
            steps {
                script {
                    // Dynamically resolves the SonarQube Scanner tool configured in Jenkins
                    def scannerHome = tool 'sonar-scanner'
                    withSonarQubeEnv('sonar-server') {
                        sh """
                            ${scannerHome}/bin/sonar-scanner \
                              -Dsonar.projectKey=manahydpropertiess \
                              -Dsonar.sources=. \
                              -Dsonar.exclusions="**/*.test.js,**/node_modules/**"
                        """
                    }
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
            // Clean up locally tagged images to prevent running out of disk space
            sh """
                docker rmi ${IMAGE_URI} || true
                docker rmi ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest || true
            """
        }
        success {
            echo "CI/CD Pipeline executed successfully. Docker image published to ${IMAGE_URI}"
        }
        failure {
            echo "Pipeline run failed. Check the stage logs above for details."
        }
    }
}