{lib, ...}: {
  cfg,
  ipv6-brackets,
  default-ip-socket ? null,
  ...
}:
with lib;
assert (ipv6-brackets == true) || (ipv6-brackets == false); let
  splitLastColon = s: let
    m = builtins.match "^(.*):([^:]*)$" s;
  in
    if m == null
    then {
      host = s;
      port = null;
    }
    else {
      host = elemAt m 0;
      port = elemAt m 1;
    };

  bracketIpv6 = s: let
    p = splitLastColon s;
  in
    if p.port == null
    then s
    else if hasPrefix "[" p.host && hasSuffix "]" p.host
    then s
    else if hasInfix ":" p.host
    then "[${p.host}]:${p.port}"
    else s;

  unbracketIpv6 = s: let
    p = splitLastColon s;
  in
    if p.port != null && hasPrefix "[" p.host && hasSuffix "]" p.host
    then "${substring 1 (stringLength p.host - 2) p.host}:${p.port}"
    else s;
in {
  port = mkOption {
    type = types.nullOr types.port;
    default = null;
  };
  host = mkOption {
    type = types.nullOr types.singleLineStr;
    default = null;
  };
  ip-socket = mkOption {
    type = types.singleLineStr;
    default =
      if cfg.host != null && cfg.port != null
      then "${cfg.host}:${toString cfg.port}"
      else default-ip-socket;
    apply =
      if ipv6-brackets
      then bracketIpv6
      else unbracketIpv6;
  };
}
