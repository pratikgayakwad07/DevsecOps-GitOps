# Blog App on AWS EKS

React frontend, Node.js API, and MySQL deployed to Amazon EKS. GitHub Actions scans, tests, builds, and pushes the images to ECR; Argo CD deploys the image tags from Git.

## First-time setup

1. Set the Terraform values in `infra/terraform.tfvars`.
   - Keep `github_owner_id` and `github_repository_id` aligned with this repository; the OIDC role only trusts this repository's `main` branch.
2. Add these GitHub Actions secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION` (use `us-east-1`)
3. Push an `infra/` change to `main`, or manually run the **Terraform** workflow. It provisions the VPC, EKS, ECR, GitHub OIDC role, EBS CSI storage, and Argo CD.
4. The application workflow uses the Terraform-created OIDC role ARN by default. Set `AWS_ROLE_ARN` as a repository secret only if you use a different AWS account or role name.
5. Push an application change to `main` to run the DevSecOps pipeline and deploy the app.

> AWS infrastructure is billable while it exists. The Terraform Destroy workflow requires you to type `DESTROY` before it can remove resources.

## Pipeline stages

1. Gitleaks, Trivy filesystem scan, and npm dependency audits.
2. Frontend and backend tests; frontend production build.
3. Docker builds, Trivy image scans, and push of commit-tagged images to ECR using GitHub OIDC.
4. Commit the new image tags to `K8's/kustomization.yaml`; Argo CD syncs them to EKS.
5. Verify frontend, backend, and MySQL rollouts on EKS, then smoke-test the frontend load balancer.

Pull requests run the scans, tests, and frontend build. AWS publishing and deployment run only for pushes to `main`.

Trivy's documented `AWS-0104` exception covers the upstream EKS node-group egress rule required for NAT-based ECR pulls and AWS APIs. `AWS-0040` covers the public EKS API endpoint required by GitHub-hosted runners; workflows restrict its source CIDR to the active runner's `/32`, and Kubernetes access still requires AWS IAM and a namespace-scoped EKS access entry.

## Check the deployment

```sh
kubectl get pods -n blog-app
kubectl get service frontend-service -n blog-app
```

Open the frontend service's `EXTERNAL-IP` or load-balancer hostname in a browser. GitHub Actions also reports deployment and smoke-test failures.
