[CmdletBinding()]
param(
    [string]$TerraformDirectory = (Join-Path $PSScriptRoot "../terraform")
)

$ErrorActionPreference = "Stop"
# Prefer the Windows launcher so PowerShell does not select gcloud.ps1.
$gcloudCommand = Get-Command gcloud.cmd -ErrorAction SilentlyContinue
if (-not $gcloudCommand) {
    $gcloudCommand = Get-Command gcloud -ErrorAction Stop
}

$testJson = & terraform "-chdir=$TerraformDirectory" output -json connectivity_test
if ($LASTEXITCODE -ne 0) {
    throw "Cannot read connectivity_test. Initialize and apply Terraform first."
}
$test = ($testJson -join "`n") | ConvertFrom-Json
if (@($test.iap_ssh_members).Count -eq 0) {
    throw "Set iap_ssh_members to your Google user/group identity in terraform.tfvars and apply first."
}

Write-Host "Checking effective NCC routes in $($test.region)..."
$routeJson = & $gcloudCommand network-connectivity hubs route-tables routes list `
    "--project=$($test.project_id)" "--hub=$($test.hub_name)" `
    "--route_table=$($test.route_table)" "--effective-location=$($test.region)" --format=json
if ($LASTEXITCODE -ne 0) {
    throw "Could not read NCC routes. Check authentication and hubViewer permissions."
}
$routes = ($routeJson -join "`n") | ConvertFrom-Json
$routes | Select-Object ipCidrRange, type, state, @{Name = "nextHopVpc"; Expression = { $_.nextHopVpcNetwork.uri }} | Format-Table -AutoSize | Out-Host
foreach ($cidr in $test.expected_cidrs) {
    $matching = @($routes | Where-Object {
        $_.ipCidrRange -eq $cidr -and $_.type -eq "VPC_PRIMARY_SUBNET" -and $_.state -eq "ACTIVE"
    })
    if ($matching.Count -eq 0) {
        throw "Missing active subnet route for $cidr. Wait for NCC convergence and check both spoke states/export ranges."
    }
}

# Both commands originate inside the source VM and target the other VM's private IP.
Write-Host "VM A -> VM B private IP $($test.vm_b.private_ip)"
& $gcloudCommand compute ssh $test.vm_a.name "--project=$($test.project_id)" `
    "--zone=$($test.vm_a.zone)" --tunnel-through-iap `
    --command "ping -n -c 4 -W 3 $($test.vm_b.private_ip)"
if ($LASTEXITCODE -ne 0) {
    throw "VM A -> VM B failed. Check IAP/OS Login access, guest readiness, ICMP firewall rules, and NCC routes."
}

Write-Host "VM B -> VM A private IP $($test.vm_a.private_ip)"
& $gcloudCommand compute ssh $test.vm_b.name "--project=$($test.project_id)" `
    "--zone=$($test.vm_b.zone)" --tunnel-through-iap `
    --command "ping -n -c 4 -W 3 $($test.vm_a.private_ip)"
if ($LASTEXITCODE -ne 0) {
    throw "VM B -> VM A failed. Check IAP/OS Login access, guest readiness, ICMP firewall rules, and NCC routes."
}

Write-Host "PASS: both subnet routes are active and private-IP pings succeeded in both directions."
