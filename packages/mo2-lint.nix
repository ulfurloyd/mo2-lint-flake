{
  pkgs,
  python,
  src,
  redirector,
  ...
}:
python.pkgs.buildPythonApplication {
  pname = "mo2-lint";
  version = "7.0.3";
  inherit src;
  format = "other";
  dontBuild = false;
  dontStrip = true;

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
  ];

  patches = [
    ../patches/nexus-install-handler-permissions.patch
    ../patches/nxm-handler-debug-logging.patch
    ../patches/protontricks.patch
    ../patches/redirector-install-permissions.patch
    ../patches/tweaks-file-permissions.patch
  ];

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
    (pkgs.lib.makeBinPath [
      pkgs.protontricks
      pkgs.p7zip
      pkgs.cabextract
      pkgs.winetricks
      pkgs.psmisc
    ])
  ];

  installPhase = ''
    mkdir -p $out/lib/mo2-lint $out/bin
    cp -r . $out/lib/mo2-lint
    cp -r "$out/lib/mo2-lint/src/steam-proton-wrapper" \
      "$out/lib/mo2-lint/steam-proton-wrapper"

    install -Dm755 \
      ${redirector}/mo2-redirector.exe \
      $out/lib/mo2-lint/dist/mo2-redirector.exe

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
