# Every project's audit logs (admin activity, data access, system event,
# policy denied) are copied to one log bucket in prj-c-logging. Each project
# still keeps its own _Required and _Default buckets.

resource "google_logging_project_bucket_config" "org_audit" {
  project        = google_project.common["logging"].project_id
  location       = local.gcp.region
  bucket_id      = "org-audit-logs"
  retention_days = local.org.log_retention_days
  description    = "Audit logs of every project in ${local.gcp.domain}"

  depends_on = [google_project_service.common]
}

resource "google_logging_organization_sink" "org_audit" {
  name             = "sk-c-logging-org-audit"
  org_id           = local.gcp.org_id
  include_children = true
  destination      = "logging.googleapis.com/${google_logging_project_bucket_config.org_audit.id}"
  filter           = "logName:\"/logs/cloudaudit.googleapis.com%2F\""
}

resource "google_project_iam_member" "org_audit_writer" {
  project = google_project.common["logging"].project_id
  role    = "roles/logging.bucketWriter"
  member  = google_logging_organization_sink.org_audit.writer_identity
}
