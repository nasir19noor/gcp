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
> GitHub Actions workflow works, and `1-org/envs/shared` is written. The
> other stages are added one by one in the order below. This README is
> updated with every change.

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
├── 2-env/envs/production/            fldr-production and its IAM
├── 2-env/envs/nonproduction/         fldr-nonproduction and its IAM
├── 3-networks/envs/production/       prj-p-shared-base: VPC, subnet, Cloud NAT, firewall baseline
├── 3-networks/envs/nonproduction/    prj-n-shared-base
├── 4-projects/                       (later) application projects, attached to the Shared VPCs
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
| 3 | `3-networks/envs/production`, `3-networks/envs/nonproduction` | `prj-<p\|n>-shared-base` as Shared VPC host; `vpc-<p\|n>-shared-base` with subnet `sb-<p\|n>-shared-base-asia-southeast1` and Private Google Access; Cloud Router and Cloud NAT; firewall baseline (deny by default, IAP SSH, internal traffic) |
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
  included too. A change to `config.yaml`, `backend.conf` or the workflow
  deploys every stage. Each plan is shown in the run summary.
- **Manual run** (Actions → terraform → Run workflow), with:
  - `action`: `plan`, `apply` (plan, then apply), or `auth-check` (sign in
    and list the state bucket only);
  - `stages`: space-separated stage folders, e.g. `1-org/envs/shared`;
    empty means all.

A stage listed in the workflow but not yet written is skipped. `0-bootstrap`
is never applied by CI.

## Cost

Folders, org policies, IAM, Shared VPC and Workload Identity Federation are
free. What costs money:

- Cloud NAT: one gateway per environment, an hourly charge plus data processed;
- log storage beyond the free allowance;
- VPC Flow Logs, which are off by default.
