{lib, ...}:
with lib; {
  options.myC = mkOption {
    type = types.anything;
  };
}
