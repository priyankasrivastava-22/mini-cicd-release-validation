# Mini CI/CD Release Validation

A local DevOps demo: code change → unit tests → Docker image → Terraform-managed Kubernetes rollout → HTTP health check. No cloud account, UI or database.

## Prerequisites
Ubuntu WSL, Python 3 + `python3-venv`, Git, Docker Desktop WSL integration, Jenkins, `kind`, `kubectl`, Terraform. Keep code under `~/projects` in Linux. Suggested RAM: 8 GB minimum, ideally 16 GB.

Install missing tools from their official documentation:
- Docker Desktop WSL: https://docs.docker.com/desktop/features/wsl/
- Jenkins Ubuntu / Java requirements: https://www.jenkins.io/doc/book/installing/linux/
- kind: https://kind.sigs.k8s.io/docs/user/quick-start/
- kubectl: https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/
- Terraform: https://developer.hashicorp.com/terraform/install

## 1 — App and Docker
```bash
cd ~/projects/mini-cicd-release-validation
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements-dev.txt
pytest -q
python app.py # in another terminal: curl http://localhost:5000/health
```
Stop the Python process (Ctrl+C), then:
```bash
docker build -t mini-release-app:dev .
docker run --rm -p 5000:5000 mini-release-app:dev
# another terminal: curl http://localhost:5000/health
```
Stop the Docker process (Ctrl+C).

## 2 — GitHub + Jenkins
Create an empty GitHub repo `mini-cicd-release-validation` (do not check *Initialize README*), then:
```bash
git init
git branch -M main
git add .
git commit -m 'Initial CI/CD demo'
git remote add origin https://github.com/YOUR_USERNAME/mini-cicd-release-validation.git
git push -u origin main
```
In Jenkins create a **Pipeline** job. Definition **Pipeline script from SCM**, Git repository URL above, branch `*/main`, script path `Jenkinsfile`. Run **Build Now**. Its test and Docker stages should run; deployment is skipped by default. If the GitHub repo is private, configure read credentials in Jenkins.

**Jenkins agent prerequisites:** Jenkins must have `python3`, `python3-venv`, `docker`, `kind`, `kubectl`, `terraform` and access to the Docker daemon; easiest for a local demo is Jenkins installed directly inside the same WSL distro. Set up PATH for the Jenkins service as needed. For WSL + Docker Desktop, verify `sudo -u jenkins docker version` and `sudo -u jenkins kind version` succeed. Restrict Docker access to trusted users: access to Docker is effectively privileged access on this machine. Restart Jenkins after changing group membership.

## 3 — Kubernetes access for Jenkins
Create local cluster as your Linux user:
```bash
kind create cluster --name mini-cicd --wait 120s
kubectl get nodes
```
Give Jenkins its own kubeconfig file and ensure paths and cluster certificates are readable:
```bash
sudo install -d -m 0700 -o jenkins -g jenkins /var/lib/jenkins/.kube
sudo install -m 0600 -o jenkins -g jenkins "$HOME/.kube/config" /var/lib/jenkins/.kube/config
sudo -u jenkins env HOME=/var/lib/jenkins KUBECONFIG=/var/lib/jenkins/.kube/config kubectl get nodes
```
On some systems, kind's kubeconfig embeds certificates and uses a Docker-internal endpoint; the Jenkins user must be able to reach the same cluster. If `kubectl get nodes` fails for Jenkins, solve that before enabling deployment.

**Terraform state:** The included `terraform/main.tf` stores its state at `/var/lib/jenkins/mini-cicd.tfstate` so it survives Jenkins workspace changes. This path assumes a native Jenkins installation under the usual `/var/lib/jenkins` home. If Jenkins runs somewhere else, adapt the backend path before deploying. Do not commit state files to Git.

## 4 — Enable full pipeline
Enable deployment by creating `.enable-deploy`:
```bash
touch .enable-deploy
git add .enable-deploy
git commit -m 'Enable Kubernetes deployment with durable state'
git push
```
Now run the Jenkins job again. It tests, builds and version-tags an image, loads it into kind, applies Terraform, waits for the rollout, then requests `/health` from an ephemeral in-cluster curl pod.

Check manually:
```bash
kubectl get pods,deployments,services -n mini-cicd
kubectl port-forward -n mini-cicd svc/mini-release-app 8081:80
# another terminal: curl http://localhost:8081/health
```

## 5 — Two release tests
- **Successful update:** Edit the message in `app.py` to `Automated release version 2 deployed successfully`. Commit and push. Run Jenkins again. Verify `/` now returns version 2 text. (By default, Jenkins builds are triggered manually; optional SCM polling/webhook can automate triggering.)
- **Blocked bad release:** Edit the `/health` handler to return `status='broken'` and commit/push. `test_health` must fail; later stages do not run. Restore `status='ok'`, commit/push, rerun.

Save screenshots: passing unit tests, successful Jenkins run, `kubectl get` resources, successful `/health` response, and failing test stage that blocks deployment.

## Caveats
This is a learning demo, not production-grade release orchestration. Its tests prevent bad code from deploying, but a post-deploy health-check failure **reports** a bad rollout rather than automatically restoring the previous release. Production additions would include rollback, separate deployment credentials, remote Terraform state, stronger supply-chain protections and proper Jenkins isolation.
