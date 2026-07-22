{
  nixpkgs.overlays = [
    (final: prev: {
      myPkgs = prev.myPkgs.overrideScope (myPkgsFinal: myPkgsPrev: {
        frappe.tags = prev.lib.makeScope prev.newScope (self: {
          base_v16 = "v16.25.0"; # https://hub.docker.com/r/frappe/base/tags
          erpnext_v16 = "v16.26.2"; # https://hub.docker.com/r/frappe/erpnext/tags
          helpdesk_v1 = "v1.26.2"; # https://github.com/frappe/helpdesk
          wiki_v3 = "v3.0.0-beta.2"; # https://github.com/frappe/wiki
          crm_v1 = "v1.77.0"; # https://github.com/frappe/crm
          insights_v3 = "v3.11.2"; # https://github.com/frappe/insights
          hrms_v16 = "v16.12.0"; # https://github.com/frappe/hrms
        });
      });
    })
  ];
}
