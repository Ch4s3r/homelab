{
  services.k3s.autoDeployCharts.flux-operator = {
    name = "flux-operator";
    repo = "oci://ghcr.io/controlplaneio-fluxcd/charts/flux-operator";
    version = "0.64.0";
    hash = "sha256-x0mb72xe/Ouq7u8T3j0jympbTNfIp/RKgg7hboBOKUQ=";
    targetNamespace = "flux-system";
    createNamespace = true;
    extraDeploy = [
      {
        apiVersion = "fluxcd.controlplane.io/v1";
        kind = "FluxInstance";
        metadata = {
          name = "flux";
          namespace = "flux-system";
        };
        spec = {
          distribution = {
            version = "2.10.x";
            registry = "ghcr.io/fluxcd";
          };
          components = [
            "source-controller"
            "kustomize-controller"
            "helm-controller"
            "notification-controller"
          ];
          cluster = {
            type = "kubernetes";
            networkPolicy = true;
            domain = "cluster.local";
          };
          sync = {
            kind = "GitRepository";
            url = "https://github.com/Ch4s3r/homelab.git";
            ref = "refs/heads/main";
            path = "clusters/macmini";
          };
        };
      }
    ];
  };
}
