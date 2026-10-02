pipeline {
  agent any
  options { timestamps(); disableConcurrentBuilds() }
  environment {
    IMAGE = 'mini-release-app'
    KUBECONFIG = "${env.HOME}/.kube/config"
  }
  stages {
    stage('Test') {
      steps {
        sh '''
          set -eu
          python3 -m venv .venv
          . .venv/bin/activate
          pip install -r requirements-dev.txt
          pytest -q
        '''
      }
    }
    stage('Build image') {
      steps {
        sh '''
          set -eu
          docker build -t "$IMAGE:$BUILD_NUMBER" .
        '''
      }
    }
    stage('Deploy + validate') {
      when { expression { return fileExists('.enable-deploy') } }
      steps {
        sh '''
          set -eu
          kind load docker-image "$IMAGE:$BUILD_NUMBER" --name mini-cicd
          cd terraform
          terraform init -input=false
          terraform apply -input=false -auto-approve -var="image=$IMAGE:$BUILD_NUMBER"
          kubectl -n mini-cicd rollout status deployment/mini-release-app --timeout=120s
          kubectl -n mini-cicd run "health-check-$BUILD_NUMBER" --rm -i --restart=Never \
            --image=curlimages/curl:8.12.1 --image-pull-policy=IfNotPresent \
            -- curl -fsS http://mini-release-app/health | grep '"status":"ok"'
        '''
      }
    }
  }

}
