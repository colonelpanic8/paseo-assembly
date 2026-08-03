{
  description = "fork-assembler maintenance repository";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    fork-assembler.url = "github:colonelpanic8/fork-assembler";
    fork-assembler.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = { nixpkgs, fork-assembler, ... }:
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
            fork-assembler-package =
              fork-assembler.packages.${system}.default.overrideAttrs (old: {
                nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.git ];
              });
          in
          pkgs.mkShell {
            packages = [
              fork-assembler-package
              pkgs.cachix
              pkgs.git
              pkgs.gh
              pkgs.jq
              pkgs.just
            ];
          };
      });

      lib.forkAssemblerAgentGuide = fork-assembler.lib.agentGuide;
    };
}
