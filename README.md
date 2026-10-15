# Blog App on AWS EKS

React frontend, Node.js API, and MySQL deployed to Amazon EKS. GitHub Actions scans, tests, builds, and pushes the images to ECR; Argo CD deploys the image tags from Git.

## First-time setup

1. Set the Terraform values in `infra/terraform.tfvars`.
2. Add these GitHub Actions secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION` (use `us-east-1`)
3. Push an `infra/` change to `main`, or manually run the **Terraform** workflow. It provisions the VPC, EKS, ECR, GitHub OIDC role, EBS CSI storage, and Argo CD.
4. Copy Terraform's `github_actions_role_arn` output into the repository secret `AWS_ROLE_ARN`.
5. Push an application change to `main` to run the DevSecOps pipeline and deploy the app.

> AWS infrastructure is billable while it exists. The Terraform Destroy workflow requires you to type `DESTROY` before it can remove resources.

## Pipeline stages

1. Gitleaks, Trivy filesystem scan, and npm dependency audits.
2. Frontend and backend tests; frontend production build.
3. Docker builds, Trivy image scans, and push of commit-tagged images to ECR using GitHub OIDC.
4. Commit the new image tags to `K8's/kustomization.yaml`; Argo CD syncs them to EKS.
5. Verify frontend, backend, and MySQL rollouts on EKS, then smoke-test the frontend load balancer.

Pull requests run the scans, tests, and frontend build. AWS publishing and deployment run only for pushes to `main`.

## Check the deployment

```sh
kubectl get pods -n blog-app
kubectl get service frontend-service -n blog-app
```

Open the frontend service's `EXTERNAL-IP` or load-balancer hostname in a browser. GitHub Actions also reports deployment and smoke-test failures.
