# gcp

Terraform landing zone for the Google Cloud organization **nasir.id**
(`1085796438163`), deployed by GitHub Actions through Workload Identity
Federation, without service account keys.

The layout and naming follow Google's security foundations blueprint
([terraform-example-foundation](https://github.com/terraform-google-modules/terraform-example-foundation),
as also used by [ollionorg/gcp-landing-zone](https://github.com/ollionorg/gcp-landing-zone)):
numbered stages, `fldr-` / `prj-<env code>-` names. It keeps only what a
small organization needs. There is no Cloud Build, no self-hosted runners,
no interconnect and no VPC Service Controls, and settings live in one
`config.yaml` instead of `terraform.tfvars` per stage.

> **Status:** `0-bootstrap` is applied (project `prj-b-seed-9d42`), the
> GitHub Actions workflow works, `1-org/envs/shared` is deployed, and
> `2-env` and `3-networks` are written, with only free resources (Cloud NAT
> off). `4-projects` comes later. This README is updated with every change.

## Decisions

| Item | Value |
|---|---|
| Organization | `nasir.id`, ID `1085796438163` |
| Identity | Cloud Identity Free, customer `C0384bjrt`; access is granted to six users (groups can replace them later) |
| Essential contact | `nasir@nasir.id` |
| Budget | IDR 160,000 (about USD 10) a month on the billing account, alerts at 50 / 90 / 100 % |
| Logs | Org-wide audit log sink to one bucket, 30-day retention |
| Org policy exceptions | VM public IPs allowed; service account keys not allowed |
| Billing account | `017E13-779EF0-74B8F6` |
| Region | `asia-southeast1` (Singapore), the only region allowed by org policy |
| Environments | `production` (code `p`), `nonproduction` (code `n`) |
| Network | production `10.10.0.0/16`, nonproduction `10.20.0.0/16`, one Shared VPC each |
| State | GCS bucket `nasir-terraform-state-bucket`, created with the `cloud-storage` module of [nasir19noor/terraform](https://github.com/nasir19noor/terraform/tree/main/gcp/modules/cloud-storage) |
| CI/CD | GitHub Actions on GitHub-hosted runners, repository `nasir19noor/gcp` (ID `1445073393`), branch `main` |
| GCP ↔ GitHub | Workload Identity Federation: the GitHub OIDC token impersonates `sa-terraform` |
| Application projects | Not yet: the landing zone comes first |

## Naming

| Resource | Pattern | Example |
|---|---|---|
| Folder | `fldr-<name>` | `fldr-common`, `fldr-production` |
| Project | `prj-<env code>-<name>-<random 4 hex>` | `prj-b-seed-3f9a`, `prj-c-logging-81c0` |
| VPC | `vpc-<env code>-shared-base` | `vpc-p-shared-base` |
| Subnet | `sb-<env code>-shared-base-<region>` | `sb-p-shared-base-asia-southeast1` |

Environment codes: `b` bootstrap, `c` common, `p` production, `n`
nonproduction. Project IDs are unique across all of Google Cloud, so each
gets a random suffix. The project name, without the suffix, is what the
console shows.

## Resource hierarchy

```
nasir.id (1085796438163)
├── fldr-bootstrap     prj-b-seed          state bucket, sa-terraform, Workload Identity pool for GitHub
├── fldr-common        prj-c-logging       org log sink and log bucket, audit log settings
│                      prj-c-billing       budgets and alert channel
├── fldr-production    prj-p-shared-base   Shared VPC host, vpc-p-shared-base 10.10.0.0/16
│                      (application projects later)
└── fldr-nonproduction prj-n-shared-base   Shared VPC host, vpc-n-shared-base 10.20.0.0/16
                       (application projects later)
```

## Repository layout

```
gcp/
├── config.yaml                       every setting; the stages read it, nothing is hard-coded
├── backend.conf                      state bucket nasir-terraform-state-bucket
├── 0-bootstrap/                      by hand, once
├── 1-org/envs/shared/                org policies, org IAM, essential contacts, fldr-common,
│                                     prj-c-logging, prj-c-billing
├── 2-env/envs/production/            fldr-production and its IAM (calls modules/env_baseline)
├── 2-env/envs/nonproduction/         fldr-nonproduction and its IAM (same files, other state)
├── 3-networks/envs/production/       prj-p-shared-base: Shared VPC, subnet, firewall baseline (calls modules/base_shared_vpc)
├── 3-networks/envs/nonproduction/    prj-n-shared-base (same files, other state)
├── 4-projects/                       (later) application projects, attached to the Shared VPCs
├── modules/env_baseline/             one environment: folder and folder IAM
├── modules/base_shared_vpc/          one environment's network: host project, VPC, subnet, firewall, optional NAT
├── docs/                             (later) detailed guide and diagrams
└── .github/workflows/terraform.yml   CI/CD: deploys the changed stages
```

Each stage folder is a separate Terraform root with its own state, under
`gs://nasir-terraform-state-bucket/<stage path>/`, e.g. `1-org/envs/shared`. A
stage reads the outputs of earlier stages through `terraform_remote_state`.
Modules come from [nasir19noor/terraform](https://github.com/nasir19noor/terraform),
pinned to a commit.

## Principals

Access is granted to six principals, set under `principals` in
`config.yaml` as IAM members with their type. They are Cloud Identity
**users** for now (`user:gcp@nasir.id`). To switch one to a Google group
later, create the group in admin.google.com and change its prefix to
`group:`; the next run moves the roles.

| Principal | Role in the landing zone | Org-level roles (1-org) |
|---|---|---|
| `gcp@nasir.id` | Organization administrators; break-glass | Organization Administrator, Folder Admin, Project Creator, Organization Policy Administrator, Security Reviewer |
| `gcp-billing@nasir.id` | Billing account and budgets | Billing Account Administrator, Organization Viewer |
| `gcp-network@nasir.id` | Shared VPCs, firewall, NAT | Compute Network Admin, Compute Shared VPC Admin, Compute Security Admin, Folder Viewer |
| `gcp-security@nasir.id` | Org policies, logs, Security Command Center | Security Reviewer, Organization Policy Viewer, Private Logs Viewer, Security Center Admin Viewer, Folder Viewer |
| `gcp-devops@nasir.id` | Deploys into application projects | none; per environment in 2-env |
| `gcp-developers@nasir.id` | Develop in nonproduction; read-only in production | none; per environment in 2-env |

## Setup, step by step

### Prerequisites (by hand)

1. Sign in as a nasir.id super admin:

   ```sh
   gcloud auth login
   gcloud config unset project                        # don't bill API calls to a project of another account
   gcloud auth application-default login
   gcloud organizations list                          # nasir.id 1085796438163
   gcloud billing accounts list                       # 017E13-779EF0-74B8F6 must be OPEN True
   ```

2. Give yourself these roles on the organization: Organization Administrator,
   Folder Admin, Project Creator, Organization Policy Administrator. Give
   yourself Billing Account Administrator on the billing account.
3. Create the six principals above in admin.google.com (users for now).
4. Remove the folders and projects that existed before the landing zone
   (`Common`, `Dev`, `Prod` and their projects).

### 0-bootstrap (by hand, once)

Creates, in one apply:

- folder `fldr-bootstrap` and project `prj-b-seed-<random>`, linked to
  billing, with the APIs every stage uses. Both are protected from deletion.
  The other stages bill their API calls to this project.
- State bucket `nasir-terraform-state-bucket` in `asia-southeast1`: versioned,
  uniform access, public access prevented.
- Service account `sa-terraform@prj-b-seed-<random>.iam.gserviceaccount.com`, with:
  - on the organization: Organization Administrator, Folder Admin, Project
    Creator, Organization Policy Administrator, Logs Configuration Writer,
    Compute Shared VPC Admin, Essential Contacts Admin;
  - on the billing account: Billing Account User, Billing Account Costs Manager;
  - on the state bucket: Storage Object Admin;
  - on `prj-b-seed`: Service Usage Consumer.

  It becomes owner of every project it creates, so it needs no project roles.
- Workload Identity pool `github` and provider `github-actions`. The provider
  accepts only tokens from repository ID `1445073393` on `refs/heads/main`.
  That identity may impersonate `sa-terraform`; no key is ever created.

The bucket doesn't exist before that apply, so the apply uses local state,
which is then moved into the bucket. `backend_override.tf` is ignored by git.

```sh
cd 0-bootstrap
printf 'terraform {\n  backend "local" {}\n}\n' > backend_override.tf
terraform init
terraform apply
rm backend_override.tf
terraform init -migrate-state -backend-config=../backend.conf    # answer "yes"
rm terraform.tfstate terraform.tfstate.backup                     # now in the bucket
```

Then, in GitHub → Settings → Secrets and variables → Actions → Variables, add
two repository variables from the outputs:

| Variable | Output |
|---|---|
| `GCP_WORKLOAD_IDENTITY_PROVIDER` | `workload_identity_provider` |
| `GCP_SERVICE_ACCOUNT` | `service_account` |

Check the sign-in: Actions → terraform → Run workflow, from `main`, with
action **auth-check**. It signs in as `sa-terraform` and lists the state
bucket, which should show `0-bootstrap/`.

### 1-org to 3-networks (GitHub Actions)

Push to `main`. The workflow applies the changed stages one at a time, in this order:

| Order | Stage | What it does |
|---|---|---|
| 1 | `1-org/envs/shared` | See [1-org](#1-org-envsshared) below |
| 2 | `2-env/envs/production`, `2-env/envs/nonproduction` | `fldr-production`, `fldr-nonproduction` and their IAM for devops and developers |
| 3 | `3-networks/envs/production`, `3-networks/envs/nonproduction` | See [3-networks](#3-networks-envsproduction-envsnonproduction) below |
| 4 | `4-projects` | Later: application projects from `config.yaml`, attached to the right Shared VPC |

### 1-org (envs/shared)

Settings: `principals` and `org` in `config.yaml`. Creates:

- **Org IAM:** the org-level roles in the [Principals](#principals) table.
  Bindings are additive, so grants made outside Terraform are kept.
- **Essential contacts:** `nasir@nasir.id`, all categories (security,
  billing, legal, technical, suspension, product updates).
- **`fldr-common`**, with:
  - **`prj-c-logging-<random>`:** log bucket `org-audit-logs` in
    `asia-southeast1`, 30-day retention. The org sink `sk-c-logging-org-audit`
    copies the audit logs of every project into it. Data Access audit logs
    are not turned on, because they are billed by volume.
  - **`prj-c-billing-<random>`:** a monthly budget of IDR 160,000 (about USD 10) on the whole
    billing account, e-mailing `nasir@nasir.id` (and the billing account
    admins) at 50 %, 90 % and 100 % of actual spend and at 100 % of forecast
    spend. A budget only alerts; it never stops spending.
- **Org policies,** on the whole organization:

  | Policy | Effect |
  |---|---|
  | `iam.allowedPolicyMemberDomains` = `C0384bjrt` | Roles can only be granted to nasir.id identities |
  | `iam.disableServiceAccountKeyCreation`, `iam.disableServiceAccountKeyUpload` | No service account keys |
  | `iam.automaticIamGrantsForDefaultServiceAccounts` | Default service accounts don't get Editor |
  | `compute.skipDefaultNetworkCreation` | New projects have no `default` network |
  | `compute.requireOsLogin` | SSH to VMs through IAM (OS Login) |
  | `compute.disableSerialPortAccess`, `compute.disableNestedVirtualization`, `compute.disableGuestAttributesAccess` | VM hardening |
  | `compute.restrictXpnProjectLienRemoval` | Shared VPC hosts can't be deleted by accident |
  | `storage.uniformBucketLevelAccess`, `storage.publicAccessPrevention` | No per-object ACLs, no public buckets |
  | `gcp.resourceLocations` = `in:asia-southeast1-locations` | Regional resources only in Singapore |

  `compute.vmExternalIpAccess` is deliberately **not** set: VMs may have
  public IPs. Org policies only block new actions; nothing that already
  exists is changed.

Notes:

- The budget currency must be the billing account's currency, which is
  `IDR` (`gcloud billing accounts describe 017E13-779EF0-74B8F6 --format="value(currencyCode)"`).
  The amount is IDR 160,000, about USD 10; adjust it in `config.yaml`.
- With domain-restricted sharing on, a change to `0-bootstrap` that grants a
  role to a non-nasir.id identity (e.g. the GitHub Workload Identity
  `principalSet`) may be refused. Existing grants are unaffected.

### 2-env (envs/production, envs/nonproduction)

Both folders hold the same files and call `modules/env_baseline`; only the
state prefix in `backend.tf` differs. The environment is the folder's name,
and its settings are `environments.<env>` in `config.yaml`. Each creates:

- folder `fldr-<env>` under the organization, protected from deletion;
- the roles in `environments.<env>.folder_roles` on that folder, inherited
  by every project later created in it:

  | Folder | `gcp-devops@nasir.id` | `gcp-developers@nasir.id` |
  |---|---|---|
  | `fldr-production` | Editor | Viewer |
  | `fldr-nonproduction` | Editor | Editor |

To add an environment, copy `2-env/envs/nonproduction` to the new name,
change the prefix in its `backend.tf`, add it under `environments` and
`naming.env_codes` in `config.yaml`, and add it to `ORDER` and `READERS` in
the workflow.

### 3-networks (envs/production, envs/nonproduction)

Same pattern as 2-env: both folders call `modules/base_shared_vpc`, and the
settings are `environments.<env>` and `network` in `config.yaml`. The VPC
and firewall use the `vpc` and `firewall` modules of
[nasir19noor/terraform](https://github.com/nasir19noor/terraform/tree/main/gcp/modules),
pinned to a commit. The subnet is a plain resource, because that repo's
`subnets` module doesn't work with google provider 6 and later. Each
environment gets:

| Resource | production | nonproduction |
|---|---|---|
| Host project, in `fldr-<env>` | `prj-p-shared-base-<random>` | `prj-n-shared-base-<random>` |
| Shared VPC (global routing) | `vpc-p-shared-base` | `vpc-n-shared-base` |
| Subnet in `asia-southeast1`, Private Google Access on, flow logs off | `sb-p-shared-base-asia-southeast1`, `10.10.0.0/20` | `sb-n-shared-base-asia-southeast1`, `10.20.0.0/20` |
| Firewall: SSH from IAP (`35.235.240.0/20`), TCP 22 | `fw-p-shared-base-allow-iap-ssh` | `fw-n-shared-base-allow-iap-ssh` |
| Firewall: all traffic from inside the environment's `/16` | `fw-p-shared-base-allow-internal` | `fw-n-shared-base-allow-internal` |
| Cloud Router and Cloud NAT | off (`nat: false`) | off (`nat: false`) |

Everything else coming in is denied by GCP's implied rule, and all outgoing
traffic is allowed. The `/16` is reserved for the environment, and the first
`/20` is its subnet.

Without Cloud NAT, a VM needs a public IP to reach the internet; Google APIs
work without one, through Private Google Access. To turn NAT on, set
`nat: true` for the environment in `config.yaml` and push. That adds
`cr-<p|n>-shared-base-asia-southeast1` and `nat-<p|n>-shared-base-asia-southeast1`.

Application projects in `4-projects` will be attached to these Shared VPCs
as service projects.

## CI/CD

[.github/workflows/terraform.yml](.github/workflows/terraform.yml) runs on
`ubuntu-latest` with Terraform 1.14.3:

- **Pull request:** `terraform fmt -check` and `validate` for the changed
  stages, including `0-bootstrap`. No GCP access, because the Workload
  Identity provider trusts `main` only.
- **Push to `main`:** sign in through Workload Identity Federation
  (`google-github-actions/auth`), then plan and apply only the changed
  stages, one job per stage, one at a time, in the order above. It stops at
  the first failure. A stage that reads a changed stage's outputs is
  included too. A change to `config.yaml`, `backend.conf`, `modules/` or
  the workflow deploys every stage. Each plan is shown in the run summary.
- **Manual run** (Actions → terraform → Run workflow), with:
  - `action`: `plan`, `apply` (plan, then apply), or `auth-check` (sign in
    and list the state bucket only);
  - `stages`: space-separated stage folders, e.g. `1-org/envs/shared`;
    empty means all.

A stage listed in the workflow but not yet written is skipped. `0-bootstrap`
is never applied by CI.

## Cost

Everything deployed so far is free: folders, projects, org policies, IAM,
Workload Identity Federation, the Shared VPCs, subnets and firewall rules.
What would cost money:

- Cloud NAT, off for now: an hourly charge per gateway, plus data processed;
- log storage beyond the free allowance (the audit log bucket keeps 30 days);
- VPC Flow Logs and Data Access audit logs, both off;
- whatever runs in application projects: VMs, public IPs, egress.
