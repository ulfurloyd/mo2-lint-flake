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
          version = "7.0.5";
          src = final.fetchFromGitHub {
            owner = "Furglitch";
            repo = "modorganizer2-linux-installer";
            rev = "427a6659c8c6c068ace49fc7d329f8b05cd0d9ed";
            hash = "sha256-wFph+55t6aWIDM3axQN604b6pOL1vbtneaPjWabIzKA=";
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
          meta.description = pkgs.mo2-lint.meta.description;
        };
      });

      checks = forAllSystems (pkgs: {
        nxm-handler-starts = pkgs.runCommand "mo2-lint-nxm-handler-version" { } ''
          export HOME=$TMPDIR
          ${pkgs.mo2-lint}/bin/mo2-lint-nxm-handler --version > $out
        '';
        # Fails `nix flake check` when the redirector wheels drift from upstream's uv.lock.
        redirector-pins =
          pkgs.runCommand "redirector-pins" { nativeBuildInputs = [ pkgs.python314 ]; }
            ''
              python3 ${./scripts/check-redirector-pins.py} \
                ${pkgs.mo2-lint.src}/uv.lock ${./packages/mo2-redirector.nix}
              touch $out
            '';
      });

      homeModules.default = import ./modules/home-module.nix self;
    };
}
