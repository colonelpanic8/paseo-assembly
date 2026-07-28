{
  description = "fork-fold maintenance repository";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    fork-fold.url = "github:colonelpanic8/fork-fold";
    fork-fold.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, fork-fold, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
    in
    {
      devShells = forAllSystems (system: {
        default =
          let
            pkgs = nixpkgs.legacyPackages.${system};
            fork-fold-package =
              fork-fold.packages.${system}.default.overrideAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.git ];
              });
          in
          pkgs.mkShell {
            packages = [
              fork-fold-package
              pkgs.git
              pkgs.gh
              pkgs.just
            ];
          };
      });

      lib.forkFoldAgentGuide = fork-fold.lib.agentGuide;
    };
}
