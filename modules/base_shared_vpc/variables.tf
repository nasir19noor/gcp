variable "env_code" {
  description = "Environment code used in names: p, n"
  type        = string
}

variable "project_prefix" {
  description = "Project name prefix, e.g. prj"
  type        = string
}

variable "folder_id" {
  description = "Numeric ID of the environment folder"
  type        = string
}

variable "billing_account" {
  description = "Billing account for the host project"
  type        = string
}

variable "region" {
  description = "Region of the subnet (and Cloud NAT)"
  type        = string
}

variable "cidr" {
  description = "The environment's whole range; internal traffic from it is allowed"
  type        = string
}

variable "subnet" {
  description = "Range of the first subnet, inside cidr"
  type        = string
}

variable "nat" {
  description = "Create a Cloud Router and Cloud NAT (billed hourly)"
  type        = bool
  default     = false
}

variable "iap_ranges" {
  description = "Identity-Aware Proxy source ranges allowed to SSH"
  type        = list(string)
}
