throw "Have you forgotten to configure your primary IPv6 address?"
# {
#   services.dnscrypt-proxy.settings.ipv6_servers = false; # Use servers reachable over IPv6 -- Do not enable if you don't have IPv6 connectivity
# }
# let
#   INTERFACE = "...";
#   ADDRESS = "...";
#   GATEWAY = "...";
# in {
#   networking = {
#     interfaces.${INTERFACE}.ipv6.addresses = [
#       {
#         address = ADDRESS;
#         prefixLength = 64;
#       }
#     ];
#     defaultGateway6 = {
#       address = GATEWAY;
#       interface = INTERFACE;
#     };
#   };
# }

