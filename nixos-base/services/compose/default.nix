{
  imports = [
    ./frappe-v16-compose
    # ./unmaintained
    ./camofox-browser-compose.nix
    ./cdp-compose.nix
    # ./default.nix
    ./hermes-agent-compose.nix
    ./keycloak-compose.nix
    ./n8n-oci-compose.nix
    ./plausible-compose.nix
  ];
}
