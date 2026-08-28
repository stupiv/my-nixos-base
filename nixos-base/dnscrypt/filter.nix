{inputs, ...}: {
  myOpt.dnscrypt.filter = ''
    ${builtins.readFile inputs.functional_blocklist}
  '';
}
