# Module-16: Production DNS Setup (OPTIONAL: needs a domain)

**Course section 16 · Status:** ☐ skipped (no domain)  ☐ validated only  ☐ done

## What this shows
Custom domains for CareConnect, a free ACM certificate with automatic DNS validation, and HTTPS through the ALB. A domain costs a few dollars a year, so this is **optional**. Without one, read the files, run `terraform validate`, and mark it "documented, not run".

## Files
- `main.tf`: Route 53 hosted zone plus an ACM wildcard certificate validated through DNS (two phases: zone first, then certificate)
- `values-https.yaml`: Helm values that put `portal` on `portal.<DOMAIN>` with HTTPS

## Run it (only with a domain)
```
cd Module-16-custom-domain-https-OPTIONAL
terraform init
terraform apply -var domain_name=example.com                          # phase 1: zone
terraform output name_servers                                         # set these at your registrar
terraform apply -var domain_name=example.com -var create_certificate=true   # phase 2: certificate
```

## What to be able to explain
How a browser finds the site (DNS), alias records, why ACM DNS validation needs no manual renewal, and where TLS ends (at the ALB).

## Screenshot (only if run)
`docs/screenshots/module-16-https.png`: the browser padlock on your domain.
