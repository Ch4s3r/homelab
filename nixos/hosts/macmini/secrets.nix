{ config, ... }:
{
  sops = {
    age.keyFile = "/var/lib/sops-nix/key.txt";
    defaultSopsFile = ../../secrets/macmini.sops.yaml;
    secrets.flux-age-key = { };
    templates."flux-sops-age.yaml" = {
      path = "/var/lib/rancher/k3s/server/manifests/flux-sops-age.yaml";
      content = ''
        apiVersion: v1
        kind: Namespace
        metadata:
          name: flux-system
        ---
        apiVersion: v1
        kind: Secret
        metadata:
          name: sops-age
          namespace: flux-system
        type: Opaque
        stringData:
          age.agekey: ${config.sops.placeholder.flux-age-key}
      '';
    };
  };
}
