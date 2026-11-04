resource "google_essential_contacts_contact" "org" {
  parent                              = local.org_parent
  email                               = local.org.essential_contact
  language_tag                        = "en"
  notification_category_subscriptions = ["ALL"]
}
