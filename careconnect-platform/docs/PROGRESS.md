# Build-out checklist

Tick these off as you make the repo yours. Each item has a "proof" so you can show it.

## Foundation
- [ ] Placeholders replaced (`<your-user>`, `<dockerhub-user>`), repo public on GitHub. *Proof: repo link.*
- [ ] `docker compose up` works; `/health` OK on all three paths. *Proof: terminal screenshot.*
- [ ] Unit tests pass locally (`python -m unittest -v`). *Proof: output.*

## CI
- [ ] PR checks green on a real pull request. *Proof: PR screenshot.*
- [ ] Added `DOCKERHUB_USERNAME` / `DOCKERHUB_TOKEN`; first tag `v1.0.0` released. *Proof: Docker Hub tags (amd64 + arm64).*
- [ ] Ran `terraform fmt -recursive infra`, committed, removed `continue-on-error` from the fmt step.

## GitOps (local)
- [ ] kind + ArgoCD bootstrapped from `root-local.yaml`. *Proof: ArgoCD UI.*
- [ ] Released `v1.0.1`; bot commit and rollout seen end to end.
- [ ] Practised rollback with `git revert`.
- [ ] Triggered self-heal: `kubectl scale` by hand, watched ArgoCD revert it.
- [ ] Killed Postgres, observed `appointment` go unready, recovered.

## AWS
- [ ] Stack `00-local-floci` applied on the emulator.
- [ ] Budget alert set in AWS.
- [ ] `10-eks` and `20-addons` applied; kubectl works.
- [ ] `root-eks.yaml` applied; ALB serves all three paths. *Proof: curl output + ALB screenshot.*
- [ ] Promoted a version through the `promote` workflow PR.
- [ ] Full teardown following runbook section 7; verified no leftovers. *Proof: empty `aws` queries.*

## Hardening (pick 2-3, write what you learned in the README)
- [ ] Trivy image scan in CI
- [ ] NetworkPolicies (default deny + allow rules)
- [ ] External Secrets Operator / Secrets Store CSI for the DB password
- [ ] Remote Terraform state (S3 + DynamoDB)
- [ ] HTTPS on a custom domain (Tier 3 folders 01-03)
- [ ] Karpenter + spot (Tier 3 folder 05)
- [ ] OpenTelemetry traces/metrics (Tier 3 folder 06)
- [ ] Argo Rollouts canary release

## Polish
- [ ] 5-minute demo recorded (`docs/DEMO.md`)
- [ ] Screenshots in README
- [ ] Two real "what went wrong" stories written down
- [ ] Runbook tested: followed 2A on a fresh machine/cluster without help
