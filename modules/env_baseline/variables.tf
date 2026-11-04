variable "folder_name" {
  description = "Display name of the environment folder, e.g. fldr-production"
  type        = string
}

variable "parent" {
  description = "Parent of the folder: organizations/<id> or folders/<id>"
  type        = string
}

variable "folder_roles" {
  description = "Roles on the folder, by IAM member (user:..., group:...)"
  type        = map(list(string))
  default     = {}
}
