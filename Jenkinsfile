pipeline {
  agent {
    kubernetes {
      yaml """
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins-sa
  volumes:
  - name: docker-config
    emptyDir: {}
  containers:
  - name: kaniko
    image: gcr.io/kaniko-project/executor:debug
    command: ["/busybox/sh", "-c", "cat"]
    tty: true
    volumeMounts:
    - name: docker-config
      mountPath: /kaniko/.docker
  - name: aws
    image: amazon/aws-cli:2.15.39
    command: ["sh", "-c", "cat"]
    tty: true
    volumeMounts:
    - name: docker-config
      mountPath: /kaniko/.docker
  - name: git
    image: alpine/git:2.45.2
    command: ["sh", "-c", "cat"]
    tty: true
"""
    }
  }
  environment {
    AWS_REGION    = 'eu-north-1'
    ECR_REPO_NAME = 'devops-ci-cd-ecr'
  }
  stages {
    stage('Checkout') {
      steps { checkout scm }
    }

    stage('Prepare ECR auth for Kaniko') {
      steps {
        container('aws') {
          sh '''
            set -euo pipefail
            AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
            echo "AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID}" > .aws_build.env
            ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
            ECR_REPO="${ECR_REGISTRY}/${ECR_REPO_NAME}"
            echo "ECR_REPO=${ECR_REPO}" >> .aws_build.env
            # Prefer Jenkins-provided GIT_COMMIT if available
            if [ -n "${GIT_COMMIT:-}" ]; then
              IMAGE_TAG=${GIT_COMMIT:0:7}
            else
              IMAGE_TAG=$(git rev-parse --short HEAD || echo "latest")
            fi
            echo "IMAGE_TAG=${IMAGE_TAG}" >> .aws_build.env

            # Write Docker auth for Kaniko
            mkdir -p /kaniko/.docker
            PASSWORD=$(aws ecr get-login-password --region ${AWS_REGION})
            AUTH=$(printf "AWS:%s" "$PASSWORD" | base64 | tr -d '\n')
            cat > /kaniko/.docker/config.json <<EOF
{"auths":{"${ECR_REGISTRY}":{"auth":"${AUTH}"}}}
EOF
          '''
        }
      }
    }

    stage('Build & Push image (Kaniko)') {
      steps {
        container('kaniko') {
          sh '''
            set -euo pipefail
            source .aws_build.env
            /kaniko/executor \
              --context "${WORKSPACE}" \
              --dockerfile app/Dockerfile \
              --destination "${ECR_REPO}:${IMAGE_TAG}" \
              --snapshotMode=redo --single-snapshot
          '''
        }
      }
    }

    stage('Bump Helm image tag in repo') {
      steps {
        withCredentials([usernamePassword(credentialsId: 'github-token', usernameVariable: 'GIT_USER', passwordVariable: 'GIT_TOKEN')]) {
          container('git') {
            sh '''
              set -euo pipefail
              source .aws_build.env
              # Update only the image.tag in the app chart values (POSIX sed)

              # corrected sed to avoid Groovy escaping issues and preserve indentation
              sed -i -E 's/^([[:space:]]*)tag:[[:space:]]*.*/\1tag: '"${IMAGE_TAG}"'/' project/charts/django-app/values.yaml


              git config user.email "ci@example.com"
              git config user.name "ci"
              git add project/charts/django-app/values.yaml
              git commit -m "chore: bump image tag to ${IMAGE_TAG}" || true

              # Push using token-authenticated remote
              REMOTE_URL=$(git config --get remote.origin.url)
              if echo "$REMOTE_URL" | grep -q "^http"; then
                AUTH_URL=$(echo "$REMOTE_URL" | sed -E "s#https://#https://${GIT_USER}:${GIT_TOKEN}@#")
                git push "$AUTH_URL" HEAD:main
              else
                echo "Remote is SSH; please switch to HTTPS or configure Jenkins SSH credentials for push."
                exit 1
              fi
            '''
          }
        }
      }
    }
  }
}
