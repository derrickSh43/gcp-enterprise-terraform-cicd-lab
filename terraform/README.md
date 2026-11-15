# GCP Terraform lab and NCC connectivity test

This directory deploys two VPCs joined by Network Connectivity Center (NCC), an NGINX application MIG behind an HTTPS load balancer, a standalone VM A (`app-vm`) in VPC A, and an `e2-micro` VM B (`test-vm-b`) in VPC B. VM A retains its configured `vm_machine_type`.

Both test VMs have private IPs only. SSH uses IAP and OS Login; only TCP 22 from `35.235.240.0/20` reaches instances tagged `ncc-test`. Inter-VPC ICMP ingress permits private-IP pings in both directions. The application MIG is separate from these test endpoints.

## Configure and deploy

1. Set the project, region, zone, and bucket settings in `terraform.tfvars`. Set `iap_ssh_members` to your real Google login, for example:

   ```hcl
   iap_ssh_members = ["user:you@example.com"]
   ```

   `your-test-account@gmail.com` is an example placeholder, not an account selected for access. An empty set grants no new SSH access. Groups use `group:team@example.com`.

2. Replace `REPLACE_WITH_YOUR_BUCKET_NAME` in `backend.tf` with an existing GCS state bucket. The backend cannot use Terraform variables and its bucket must exist before `terraform init`; bootstrap it separately if necessary. The storage resource in this same configuration cannot create the backend bucket before initialization. If you bootstrap the bucket that `storage.tf` manages, import it after initialization rather than attempting to create it again:

   ```powershell
   terraform -chdir=terraform import google_storage_bucket.terraform_state YOUR_EXISTING_BUCKET_NAME
   ```

3. Install Terraform, the Google Cloud CLI, and an SSH client. Authenticate gcloud as the identity in `iap_ssh_members` (`gcloud.cmd auth login` on Windows). The Google provider reads the local credentials file; GCS backend authentication is separate, for example application-default credentials via `gcloud.cmd auth application-default login`. Keep credential/key files local and ignored by Git.

4. Ensure Compute Engine, IAM, and Network Connectivity APIs are enabled. Terraform enables IAP and OS Login APIs. The Terraform deployment identity needs permissions to create the resources, enable those APIs, and manage project, instance, IAP, and service account IAM grants. Test users receive instance-scoped OS Login (without sudo), IAP tunnel access restricted to port 22, project Compute Viewer, project NCC Hub Viewer, and Service Account User on the attached application service account. Cross-organization OS Login users additionally need `roles/compute.osLoginExternalUser` from an organization administrator.

5. Run these commands from the repository root and review the plan before applying:

   ```powershell
   terraform -chdir=terraform init
   terraform -chdir=terraform fmt -check
   terraform -chdir=terraform validate
   terraform -chdir=terraform plan -out=tfplan
   terraform -chdir=terraform apply tfplan
   ```

   Existing VM A loses its public IP and uses OS Login after this change. Allow time for VM startup, IAM propagation, and NCC convergence. These private-only test VMs have no general internet egress/NAT; use the default Debian cloud image with SSH, OS Login, and ping already available.

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

The state bucket has `prevent_destroy = true`; a whole-stack destroy will be blocked until that protection is deliberately handled. Keep the state bucket available while managing the deployment.

References: [IAP TCP forwarding](https://docs.cloud.google.com/iap/docs/using-tcp-forwarding), [OS Login setup](https://docs.cloud.google.com/compute/docs/oslogin/set-up-oslogin), [NCC effective routes](https://docs.cloud.google.com/network-connectivity/docs/network-connectivity-center/how-to/vpc-view-hub-route-table).
