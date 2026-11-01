{
  pkgs,
  python,
  src,
  redirector,
  ...
}:
let
  runtimeBinPath = pkgs.lib.makeBinPath (
    with pkgs;
    [
      protontricks
      p7zip
      cabextract
      winetricks
      psmisc
      xdg-utils
      desktop-file-utils
      bubblewrap
    ]
  );
in
python.pkgs.buildPythonApplication {
  pname = "mo2-lint";
  version = "7.0.3";
  inherit src;
  format = "other";
  dontBuild = false;
  dontStrip = true;
  doCheck = true;

  patches = [
    ../patches/nexus-install-handler-permissions.patch
    ../patches/nxm-handler-debug-logging.patch
    ../patches/nxm-launcher-service.patch
    ../patches/protontricks.patch
    ../patches/redirector-install-permissions.patch
    ../patches/tweaks-file-permissions.patch
    ../patches/proton-wrapper-launcher-service.patch
  ];

  postPatch = ''
    substituteInPlace src/mo2-lint/util/nexus/install_handler.py \
      --replace-fail "copy2(internal_path, output)" \
                     "output.unlink(missing_ok=True); copy2(internal_path, output)"
  '';

  buildPhase = ''
    runHook preBuild

    pyinstaller --clean --noconfirm --onefile \
      --name nxm-handler \
      --paths src \
      --paths ${pkgs.protontricks}/lib/python3.14/site-packages \
      --hidden-import find_heroic_install \
      --hidden-import protontricks \
      --hidden-import pydantic_core \
      --add-data "src/nxm-handler:src" \
      --add-data "src/shared:src/shared" \
      --runtime-hook "build/runtime_hooks.py" \
      --additional-hooks-dir "build/hooks" \
      src/nxm-handler/__init__.py

    runHook postBuild
  '';

  nativeBuildInputs = [
    python.pkgs.pyinstaller
    pkgs.makeWrapper
  ];

  nativeCheckInputs = [
    pkgs.protontricks
  ];

  checkPhase = ''
    runHook preCheck

    export PYTHONPATH="$PWD/src/mo2-lint:$PWD/src''${PYTHONPATH:+:$PYTHONPATH}"
    ${python}/bin/python -m unittest discover -s tests -v

    runHook postCheck
  '';

  dependencies = with python.pkgs; [
    certifi
    click
    inquirerpy
    loguru
    packaging
    patool
    pillow
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
    runtimeBinPath
  ];

  installPhase = ''
    mkdir -p $out/lib/mo2-lint $out/bin
    cp -r . $out/lib/mo2-lint
    cp -r "$out/lib/mo2-lint/src/steam-proton-wrapper" \
      "$out/lib/mo2-lint/steam-proton-wrapper"

    install -Dm755 \
      ${redirector}/mo2-redirector.exe \
      $out/lib/mo2-lint/dist/mo2-redirector.exe

    mkdir -p $out/libexec
    mv $out/lib/mo2-lint/dist/nxm-handler $out/libexec/nxm-handler-bin
    makeWrapper $out/libexec/nxm-handler-bin $out/bin/mo2-lint-nxm-handler \
      --prefix PATH : ${runtimeBinPath}

    cat > $out/lib/mo2-lint/dist/nxm-handler <<'STUB'
    #!/bin/sh
    PATH="$PATH:$HOME/.nix-profile/bin:/etc/profiles/per-user/$(id -un)/bin:/run/current-system/sw/bin"
    if ! command -v mo2-lint-nxm-handler >/dev/null 2>&1; then
      log="''${XDG_CACHE_HOME:-$HOME/.cache}/mo2-lint/logs/nxm-stub.log"
      mkdir -p "$(dirname "$log")"
      echo "$(date -Is) mo2-lint-nxm-handler not found; PATH=$PATH" >> "$log"
      exit 127
    fi
    exec mo2-lint-nxm-handler "$@"
    STUB
    chmod +x $out/lib/mo2-lint/dist/nxm-handler

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

  meta = {
    description = "MO2-LINT packaged for NixOS";
    license = pkgs.lib.licenses.gpl3;
    platforms = [ "x86_64-linux" ];
  };
}
