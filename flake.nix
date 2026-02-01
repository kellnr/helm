{
  description = "Kellnr Helm chart development environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            kubernetes-helm
            kubeconform
            chart-testing
            kind
            kubectl
            yq-go
          ];

          shellHook = ''
            echo "Kellnr Helm development environment"
            echo "Available tools: helm, kubeconform, ct, kind, kubectl, yq"
          '';
        };
      }
    );
}
