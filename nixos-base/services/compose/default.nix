{
  imports = [
    ./frappe-v16-compose
    # ./unmaintained
    # ./default.nix
    ./hermes-agent-compose.nix
    ./keycloak-compose.nix
    ./n8n-compose.nix
    ./plausible-compose.nix
  ];
}
