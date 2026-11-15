# GCP Terraform lab and NCC connectivity test

This directory deploys two VPCs joined by Network Connectivity Center (NCC), an NGINX application MIG behind an HTTPS load balancer, a standalone VM A (`app-vm`) in VPC A, and an `e2-micro` VM B (`test-vm-b`) in VPC B. VM A retains its configured `vm_machine_type`.

Both test VMs have private IPs only. SSH uses IAP and OS Login; only TCP 22 from `35.235.240.0/20` reaches instances tagged `ncc-test`. Inter-VPC ICMP ingress permits private-IP pings in both directions. The application MIG is separate from these test endpoints.

## Configure and deploy

Environment-specific identifiers are supplied through GitHub Actions variables or ignored local files. The public source has no project ID, deployment service account email, state-bucket name, or Workload Identity provider identifier embedded in it. This separates configuration from source; repository variables are not a secret store, and resource identifiers can still appear in Terraform plan logs.

### GitHub Actions

Configure these repository variables with GitHub CLI (`gh variable set NAME --body VALUE --repo OWNER/REPOSITORY`):

| Variable | Value |
| --- | --- |
| `GCP_PROJECT_ID` | Target project ID |
| `GCP_REGION` | Compute region |
| `GCP_ZONE` | Test VM zone within the region |
| `GCP_SERVICE_ACCOUNT` | Deployment service account email |
| `GCP_WIF_PROVIDER` | Full Workload Identity provider resource name |
| `TF_STATE_BUCKET` | Existing GCS state bucket |
| `TF_STATE_PREFIX` | Existing state object prefix |
| `GCP_SSL_CERTIFICATE_NAME` | Existing global Compute Engine SSL certificate name |

The manual workflow authenticates with Workload Identity, initializes the partial GCS backend with the configured bucket/prefix, validates Terraform, and runs a plan. It does not apply changes. The existing certificate is looked up by name; neither the workflow nor Terraform reads its private key. No certificate restoration step or TLS GitHub secrets are needed by this workflow.

The backend bucket and certificate must exist before running the workflow. Keep the original bucket and prefix when using existing state. Enable Compute Engine, IAM, and Network Connectivity APIs; Terraform enables IAP and OS Login APIs. The deployment identity needs permissions to manage the resources, enable those APIs, manage the IAM grants, read the certificate, and read/write the GCS state. Workload Identity must trust this repository and permit impersonation of the deployment service account.

### Local PowerShell

1. Set `project_id`, `region`, `zone`, `state_bucket_name`, and `ssl_certificate_name` in ignored `terraform/terraform.tfvars`. Keep the rest of your environment overrides there as needed. For SSH access, set your real login:

   ```hcl
   iap_ssh_members = ["user:you@example.com"]
   ```

   An empty set grants no new SSH access. Groups use `group:team@example.com`.

2. Keep `bucket` and `prefix` in ignored `terraform/backend.local.tfbackend`. These settings are separate from Terraform input variables. The local file has been prepared with the existing backend values. For a new checkout, create it with your own bucket and state prefix:

   ```hcl
   bucket = "YOUR_EXISTING_STATE_BUCKET"
   prefix = "YOUR_STATE_PREFIX"
   ```

3. Authenticate locally using Application Default Credentials (`gcloud.cmd auth application-default login`) or set `GOOGLE_APPLICATION_CREDENTIALS` to the path of your ignored local credentials file. Authenticate gcloud separately as the identity in `iap_ssh_members` using `gcloud.cmd auth login` for SSH and route checks. GitHub Actions supplies its own credentials through Workload Identity.

4. From the repository root, initialize using the local backend file and review the plan:

   ```powershell
   terraform -chdir=terraform init -reconfigure "-backend-config=backend.local.tfbackend"
   terraform -chdir=terraform fmt -check
   terraform -chdir=terraform validate
   terraform -chdir=terraform plan -out=tfplan
   # Apply only after reviewing the plan:
   terraform -chdir=terraform apply tfplan
   ```

The test users receive instance-scoped OS Login without sudo, IAP SSH limited to port 22, Compute Viewer, NCC Hub Viewer, and Service Account User on the attached application service account. Cross-organization OS Login users additionally need `roles/compute.osLoginExternalUser` from an organization administrator.

VM A uses private-only networking and OS Login. Allow time for VM startup, IAM propagation, and NCC convergence. These private-only test VMs have no general internet egress/NAT; use the default Debian cloud image with SSH, OS Login, and ping already available.

## Run the connectivity and route checks

From the repository root in PowerShell:

```powershell
./scripts/test-ncc.ps1
```

If Windows blocks `.ps1` execution, you can run this local script with a process-only policy override (no persistent policy change):

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ./scripts/test-ncc.ps1
```

The script reads deployed addresses from Terraform outputs, lists effective NCC routes for the configured region, requires active primary-subnet routes for both CIDRs, and runs four pings from each test VM to the other's private IP over IAP SSH. It stops on failed commands or missing routes. It does not apply or modify infrastructure. gcloud might prompt to create your local SSH key on the first connection.

For manual terminal access and checks, run:

```powershell
$test = terraform -chdir=terraform output -json connectivity_test | ConvertFrom-Json

# Open VM A's terminal. Inside it, ping VM B's private_ip from the output.
gcloud.cmd compute ssh $test.vm_a.name "--project=$($test.project_id)" "--zone=$($test.vm_a.zone)" --tunnel-through-iap

# Open VM B's terminal. Inside it, ping VM A's private_ip from the output.
gcloud.cmd compute ssh $test.vm_b.name "--project=$($test.project_id)" "--zone=$($test.vm_b.zone)" --tunnel-through-iap

# Check hub/spoke state and the effective regional routes.
gcloud.cmd network-connectivity hubs list-spokes "--hub=$($test.hub_name)" "--project=$($test.project_id)"
gcloud.cmd network-connectivity hubs route-tables list "--hub=$($test.hub_name)" "--project=$($test.project_id)"
gcloud.cmd network-connectivity hubs route-tables routes list "--hub=$($test.hub_name)" "--route_table=$($test.route_table)" "--effective-location=$($test.region)" "--project=$($test.project_id)" --format=json
```

Use `gcloud` in place of `gcloud.cmd` on Linux/macOS. With the default CIDRs, expect active `VPC_PRIMARY_SUBNET` routes for `10.231.0.0/24` and `10.230.0.0/24` through their respective VPC spokes in `default-route-table`. Check both spokes are active and that their `include_export_ranges` match the subnet CIDRs if a route is missing. Ping success verifies the end-to-end data path; route visibility alone does not verify firewall access.

The existing state bucket and certificate are managed outside this configuration. Keep the state bucket available while managing the deployment.

References: [IAP TCP forwarding](https://docs.cloud.google.com/iap/docs/using-tcp-forwarding), [OS Login setup](https://docs.cloud.google.com/compute/docs/oslogin/set-up-oslogin), [NCC effective routes](https://docs.cloud.google.com/network-connectivity/docs/network-connectivity-center/how-to/vpc-view-hub-route-table).
