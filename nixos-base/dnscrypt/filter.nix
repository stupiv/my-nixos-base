{inputs, ...}: {
  myOpt.dnscrypt.filter = ''
    ${builtins.readFile (inputs.oisd + /domainswild_big.txt)}
  '';
}
