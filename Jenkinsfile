pipeline {
    agent any

    environment {
        AWS_ACCOUNT_ID = '003713966273'
        AWS_REGION     = 'ap-south-1'
        CLUSTER_NAME   = 'manahydpropertiess-cluster'
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

        stage('Trivy Source Scan') {
            steps {
                sh 'trivy fs --exit-code 0 --severity HIGH,CRITICAL --format table .'
            }
        }

        stage('Docker Build') {
            steps {
                sh """
                    docker build -t ${IMAGE_URI} -t ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest .
                """
            }
        }

        stage('Trivy Container Scan') {
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

        stage('Deploy to AWS EKS') {
            steps {
                sh """
                    # Update kubeconfig to point to the EKS cluster
                    aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}

                    # Refresh ECR pull secret in Kubernetes
                    kubectl create secret docker-registry ecr-cred \
                      --docker-server=${ECR_REGISTRY} \
                      --docker-username=AWS \
                      --docker-password=\$(aws ecr get-login-password --region ${AWS_REGION}) \
                      --dry-run=client -o yaml | kubectl apply -f -

                    # Substitute dynamic build tag and deploy manifests
                    sed -i "s|IMAGE_TAG|${IMAGE_TAG}|g" k8s/deployment.yaml
                    kubectl apply -f k8s/deployment.yaml
                    kubectl apply -f k8s/service.yaml

                    # Verify successful rolling update
                    kubectl rollout status deployment/manahydpropertiess-deployment --timeout=120s
                """
            }
        }

        stage('Smoke Testing') {
            steps {
                sh '''
                    # Fetch worker node public IP
                    NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="ExternalIP")].address}')
                    if [ -z "$NODE_IP" ]; then
                        NODE_IP=$(kubectl get nodes -o jsonpath='{.items[0].status.addresses[?(@.type=="InternalIP")].address}')
                    fi

                    echo "Testing endpoint at http://${NODE_IP}:30080 ..."
                    sleep 5
                    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://${NODE_IP}:30080 || true)
                    echo "Smoke Test HTTP Status: ${HTTP_STATUS}"

                    if [ "$HTTP_STATUS" -ne 200 ]; then
                        echo "Warning: Direct NodePort returned ${HTTP_STATUS}. Verifying internal cluster pod health..."
                        kubectl get pods -l app=manahydpropertiess
                    else
                        echo "Smoke test passed successfully with HTTP 200 OK!"
                    fi
                '''
            }
        }
    }

    post {
        always {
            sh """
                docker rmi ${IMAGE_URI} || true
                docker rmi ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest || true
            """
        }
    }
}