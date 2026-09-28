{
  lib,
  newScope,
}: (lib.makeScope newScope (self: rec {
  base_v16 = "v16.35.0"; # https://hub.docker.com/r/frappe/base/tags
  build_v16 = "v16.36.0"; # https://hub.docker.com/r/frappe/build/tag
  crm_v1 = "v1.85.0"; # https://github.com/frappe/crm/tags
  wiki_v3 = "v3.2.1"; # https://github.com/frappe/wiki/tags
  erpnext_v16 = build_v16;
  # helpdesk_v1 = "v1.30.0"; # https://github.com/frappe/helpdesk/tags
  # insights_v3 = "v3.12.6"; # https://github.com/frappe/insights/tags
  # hrms_v16 = "v16.17.0"; # https://github.com/frappe/hrms/tags
}))
