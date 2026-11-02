{
  description = "MO2-LINT packaged for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system: f (nixpkgs.legacyPackages.${system}.extend self.overlays.default)
        );
    in
    {
      overlays.default =
        final: _prev:
        let
          version = "7.0.3";
          src = final.fetchFromGitHub {
            owner = "Furglitch";
            repo = "modorganizer2-linux-installer";
            rev = "7be2fe2359953c9cdbb99eb47a297ab3e8ec504b";
            hash = "sha256-qybjSUmfVjw9NrRFbPClKGOYvCT6llcoLJ6jK/59J34=";
          };
          redirector = final.callPackage ./packages/mo2-redirector.nix { inherit src version; };
        in
        {
          mo2-redirector = redirector;
          mo2-lint = final.callPackage ./packages/mo2-lint.nix {
            inherit src version redirector;
            python = final.python314;
          };
        };

      packages = forAllSystems (pkgs: {
        default = pkgs.mo2-lint;
        mo2-lint = pkgs.mo2-lint;
        mo2-redirector = pkgs.mo2-redirector;
      });

      apps = forAllSystems (pkgs: {
        default = {
          type = "app";
          program = "${pkgs.mo2-lint}/bin/mo2-lint";
        };
      });

      checks = forAllSystems (pkgs: {
        nxm-handler-starts = pkgs.runCommand "mo2-lint-nxm-handler-version" { } ''
          export HOME=$TMPDIR
          ${pkgs.mo2-lint}/bin/mo2-lint-nxm-handler --version > $out
        '';
      });

      homeModules.default = import ./modules/home-module.nix self;
    };
}
