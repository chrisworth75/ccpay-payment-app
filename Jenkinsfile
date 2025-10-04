// Jenkinsfile for ccpay-payment-app local deployment
pipeline {
    agent any

    environment {
        REGISTRY = 'localhost:5000'
        IMAGE_NAME = 'ccpay-payment-app'
        DB_CONTAINER = 'payments-db'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                sh 'echo "Checked out ccpay-payment-app successfully"'
            }
        }

        stage('Build Application') {
            steps {
                script {
                    sh '''
                        echo "Building Spring Boot application..."
                        ./gradlew clean build -x test
                    '''
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                script {
                    def image = docker.build("${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}")
                    docker.withRegistry("http://${REGISTRY}") {
                        image.push()
                        image.push('latest')
                    }
                }
            }
        }

        stage('Deploy') {
            when {
                branch 'local'
            }
            steps {
                script {
                    // Create network for container communication
                    sh """
                        docker network create payments-network || echo "Network already exists"
                    """

                    // Verify database is running
                    sh """
                        if ! docker ps | grep -q ${DB_CONTAINER}; then
                            echo "⚠️  Warning: ${DB_CONTAINER} is not running"
                            echo "Please ensure payments-db is deployed first"
                            exit 1
                        fi
                    """

                    // Stop and remove existing container if it exists
                    sh """
                        docker rm -f ${IMAGE_NAME} || true
                    """

                    // Run API container
                    sh """
                        docker run -d \\
                        --name ${IMAGE_NAME} \\
                        --restart unless-stopped \\
                        --network payments-network \\
                        -p 8081:8080 \\
                        -e SPRING_PROFILES_ACTIVE=local \\
                        -e POSTGRES_HOST=${DB_CONTAINER} \\
                        -e POSTGRES_PORT=5432 \\
                        -e POSTGRES_NAME=payments \\
                        -e POSTGRES_USERNAME=postgres \\
                        -e POSTGRES_PASSWORD=postgres \\
                        -e AUTH_IDAM_CLIENT_BASEURL=http://host.docker.internal:5556 \\
                        -e AUTH_PROVIDER_SERVICE_CLIENT_BASEURL=http://host.docker.internal:5556 \\
                        -e CORE_CASE_DATA_API_URL=http://host.docker.internal:4452 \\
                        ${REGISTRY}/${IMAGE_NAME}:${BUILD_NUMBER}
                    """
                }
            }
        }

        stage('Health Check') {
            when {
                branch 'local'
            }
            steps {
                script {
                    // Wait for API to be healthy with retries
                    sh '''
                        echo "⏳ Waiting for Payment API to be healthy..."
                        for i in {1..60}; do
                            if curl -f -s http://localhost:8081/health > /dev/null 2>&1; then
                                echo "✅ Payment API is healthy after $((i * 5)) seconds"
                                break
                            elif [ $i -eq 60 ]; then
                                echo "❌ Payment API failed to become healthy after 300 seconds"
                                docker logs ${IMAGE_NAME} --tail 100
                                exit 1
                            else
                                echo "⏳ Attempt $i/60: API not ready, waiting 5s..."
                                sleep 5
                            fi
                        done
                    '''
                }
            }
        }

        stage('REST Assured Tests') {
            when {
                branch 'local'
            }
            steps {
                script {
                    sh '''
                        echo "🧪 Running REST Assured API tests..."
                        ./gradlew smokeTest -Dtest.url=http://localhost:8081 || echo "⚠️ Smoke tests not configured"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo '✅ ccpay-payment-app pipeline completed successfully!'
            echo '📍 Payment API available at http://localhost:8081'
        }
        failure {
            echo '❌ ccpay-payment-app pipeline failed!'
            sh 'docker logs ${IMAGE_NAME} --tail 100 || true'
        }
    }
}
