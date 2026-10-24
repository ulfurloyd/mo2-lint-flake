{
  description = "MO2-LINT packaged for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      python = pkgs.python314;
      src = pkgs.fetchFromGitHub {
        owner = "Furglitch";
        repo = "modorganizer2-linux-installer";
        rev = "7be2fe2359953c9cdbb99eb47a297ab3e8ec504b";
        hash = "sha256-qybjSUmfVjw9NrRFbPClKGOYvCT6llcoLJ6jK/59J34=";
      };
      redirector = pkgs.callPackage ./packages/mo2-redirector.nix {
        inherit src;
      };
      mo2Lint = pkgs.callPackage ./packages/mo2-lint.nix {
        inherit src python redirector;
      };
    in
    {
      packages.${system} = {
        default = mo2Lint;
        mo2-lint = mo2Lint;
        mo2-redirector = redirector;
      };
      apps.${system}.default = {
        type = "app";
        program = "${mo2Lint}/bin/mo2-lint";
        meta = mo2Lint.meta;
      };
      overlays.default = final: prev: {
        mo2-lint = mo2Lint;
        mo2-redirector = redirector;
      };
    };
}
