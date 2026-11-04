# Org policies only block new actions: nothing that already exists is
# changed or removed. They are applied after this stage's own IAM grants,
# because domain-restricted sharing would otherwise reject the grant to the
# log sink's Google-managed writer identity.

resource "google_org_policy_policy" "enforce" {
  for_each = toset(local.org.policies.enforce)
  name     = "${local.org_parent}/policies/${each.value}"
  parent   = local.org_parent

  spec {
    rules {
      enforce = "TRUE"
    }
  }

  depends_on = [google_project_iam_member.org_audit_writer, google_organization_iam_member.principals]
}

# Only members of the nasir.id Cloud Identity customer can be granted roles.
resource "google_org_policy_policy" "domain_restricted_sharing" {
  name   = "${local.org_parent}/policies/iam.allowedPolicyMemberDomains"
  parent = local.org_parent

  spec {
    rules {
      values {
        allowed_values = [local.gcp.customer_id]
      }
    }
  }

  depends_on = [google_project_iam_member.org_audit_writer, google_organization_iam_member.principals]
}

resource "google_org_policy_policy" "resource_locations" {
  name   = "${local.org_parent}/policies/gcp.resourceLocations"
  parent = local.org_parent

  spec {
    rules {
      values {
        allowed_values = local.org.policies.allowed_locations
      }
    }
  }

  # The log bucket is created first, in the allowed region anyway.
  depends_on = [google_logging_project_bucket_config.org_audit]
}
