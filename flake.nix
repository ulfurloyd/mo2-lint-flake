{
  description = "MO2-LINT packaged for NixOS";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      python = pkgs.python313;
      src = pkgs.fetchFromGitHub {
        owner = "Furglitch";
        repo = "modorganizer2-linux-installer";
        rev = "7be2fe2359953c9cdbb99eb47a297ab3e8ec504b";
        hash = "sha256-qybjSUmfVjw9NrRFbPClKGOYvCT6llcoLJ6jK/59J34=";
      };
    in
    {
      packages.${system}.mo2-lint = python.pkgs.buildPythonApplication {
        pname = "mo2-lint";
        version = "7.0.3";
        inherit src;
        format = "other";
        dontBuild = true;

        postBuild = ''
          pyinstaller --clean --noconfirm --onefile \
            --name nxm-handler \
            --paths src \
            --hidden-import find_heroic_install \
            --hidden-import protontricks \
            --hidden-import pydantic_core \
            --add-data "src/nxm-handler:src" \
            --add-data "src/shared:src/shared" \
            --runtime-hook "build/runtime_hooks.py" \
            --additional-hooks-dir "build/hooks" \
            src/nxm-handler/__init__.py
        '';

        nativeBuildInputs = [
          python.pkgs.pyinstaller
        ];

        postPatch = ''
          substituteInPlace src/mo2-lint/__init__.py \
            --replace-fail \
              '        copy2(tweaks_file, edit_file)' \
              '        edit_file.unlink(missing_ok=True)
                  copy2(tweaks_file, edit_file)
                  edit_file.chmod(0o644)'
          patch -p1 < ${./protontricks.patch}
        '';

        dependencies = with python.pkgs; [
          certifi
          click
          inquirerpy
          loguru
          packaging
          patool
          psutil
          pydantic-core
          pyyaml
          requests
          send2trash
          websockets
          vdf
        ];

        makeWrapperArgs = [
          "--prefix"
          "PATH"
          ":"
          (pkgs.lib.makeBinPath [
            pkgs.protontricks
            pkgs.p7zip
            pkgs.cabextract
            pkgs.winetricks
          ])
        ];

        installPhase = ''
          mkdir -p $out/lib/mo2-lint $out/bin
          cp -r . $out/lib/mo2-lint

          cat > $out/bin/mo2-lint <<EOF
          #!${python}/bin/python3
          import runpy
          import sys

          sys.path.insert(0, "$out/lib/mo2-lint/src/mo2-lint")
          sys.path.insert(0, "$out/lib/mo2-lint/src")
          runpy.run_path("$out/lib/mo2-lint/src/mo2-lint/__init__.py", run_name = "__main__")
          EOF

          chmod +x $out/bin/mo2-lint
        '';
      };
    };
}
