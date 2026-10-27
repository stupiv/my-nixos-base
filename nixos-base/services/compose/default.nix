{
  imports = [
    ./frappe-compose
    # ./unmaintained
    ./WIP
    # ./default.nix
    ./keycloak-compose.nix
    ./n8n-compose.nix
    ./plausible-compose.nix
  ];
}
