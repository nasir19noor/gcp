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

> **Status:** `0-bootstrap` is applied (project `prj-b-seed-9d42`) and the
> GitHub Actions workflow is written. The other stages are added one by one
> in the order below. This README is updated with every change.

## Decisions

| Item | Value |
|---|---|
| Organization | `nasir.id`, ID `1085796438163` |
| Identity | Cloud Identity Free, customer `C0384bjrt`; groups are created by hand |
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
├── 2-env/envs/production/            fldr-production and its group IAM
├── 2-env/envs/nonproduction/         fldr-nonproduction and its group IAM
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

## Groups

All access is granted to groups, never to individual users. Create these in
admin.google.com → Directory → Groups. Cloud Identity Free includes groups.

| Group | Role in the landing zone |
|---|---|
| `gcp@nasir.id` | Organization administrators; break-glass |
| `gcp-billing@nasir.id` | Billing account and budgets |
| `gcp-network@nasir.id` | Shared VPCs, firewall, NAT |
| `gcp-security@nasir.id` | Org policies, logs, Security Command Center |
| `gcp-devops@nasir.id` | Deploys into application projects |
| `gcp-developers@nasir.id` | Develop in nonproduction; read-only in production |

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
3. Create the groups above and add yourself to `gcp@nasir.id`.
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
| 1 | `1-org/envs/shared` | Group IAM at org level; essential contacts; folder `fldr-common` with `prj-c-logging` (aggregated org sink of audit logs to a log bucket, Data Access audit logs for selected services) and `prj-c-billing` (budgets at 50 / 90 / 100 %). Org policies: domain-restricted sharing (`C0384bjrt`), no service account keys, no automatic grants to default service accounts, no default network, no VM external IPs, OS Login, no serial port, no nested virtualization, no public Cloud SQL IPs, uniform bucket access, Shared VPC lien removal restricted, resource locations `asia-southeast1` |
| 2 | `2-env/envs/production`, `2-env/envs/nonproduction` | `fldr-production`, `fldr-nonproduction` and their group IAM |
| 3 | `3-networks/envs/production`, `3-networks/envs/nonproduction` | `prj-<p\|n>-shared-base` as Shared VPC host; `vpc-<p\|n>-shared-base` with subnet `sb-<p\|n>-shared-base-asia-southeast1` and Private Google Access; Cloud Router and Cloud NAT; firewall baseline (deny by default, IAP SSH, internal traffic) |
| 4 | `4-projects` | Later: application projects from `config.yaml`, attached to the right Shared VPC |

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
