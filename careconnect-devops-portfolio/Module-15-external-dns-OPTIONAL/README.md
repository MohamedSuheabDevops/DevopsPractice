# Module-15: Terraform EKS with ExternalDNS (OPTIONAL: needs a domain)

**Course section 15 · Status:** ☐ skipped (no domain)  ☐ validated only  ☐ done

## What this shows
ExternalDNS creates Route 53 DNS records automatically from your Ingresses. This needs a domain name in a Route 53 hosted zone, so it is **optional**. If you have no domain, keep the files, run only `terraform validate`, and mark it "documented, not run" in the main README.

## Files
`main.tf` creates a least-privilege IAM role for ExternalDNS (Pod Identity) and installs the ExternalDNS Helm chart restricted to your domain.

## Run it (only with a domain)
```
cd Module-15-external-dns-OPTIONAL
terraform init
terraform apply -var domain_name=example.com -var zone_id=<hosted-zone-id>
kubectl logs -n kube-system deploy/external-dns
```

## What to be able to explain
Ingress creates the ALB, ExternalDNS writes the DNS record, `txtOwnerId` marks records it owns, and `policy` (`sync` vs `upsert-only`).

## Screenshot (only if run)
`docs/screenshots/module-15-externaldns-log.png`: the log line showing a record created.
