{
  lib,
  newScope,
}: (lib.makeScope newScope (self: {
  base_v16 = "v16.31.0"; # https://hub.docker.com/r/frappe/base/tags
  erpnext_v16 = "v16.33.0"; # https://hub.docker.com/r/frappe/erpnext/tags
  helpdesk_v1 = "v1.30.0"; # https://github.com/frappe/helpdesk
  crm_v1 = "v1.82.0"; # https://github.com/frappe/crm
  insights_v3 = "v3.12.6"; # https://github.com/frappe/insights
  hrms_v16 = "v16.17.0"; # https://github.com/frappe/hrms
  # wiki_v3 = "v3.0.0-beta.2"; # https://github.com/frappe/wiki
}))
