{
  lib,
  pkgs,
  python,
  src,
  version,
  redirector,
  withSteamRun ? true,
}:
let
  runtimeDeps = with pkgs; [
      protontricks
      p7zip
      cabextract
      winetricks
      psmisc
      xdg-utils
      desktop-file-utils
      bubblewrap
  ];
  runtimeBinPath = lib.makeBinPath runtimeDeps;
  handlerBinPath = lib.makeBinPath (runtimeDeps ++ lib.optional withSteamRun pkgs.steam-run-free);
in
python.pkgs.buildPythonApplication {
  pname = "mo2-lint";
  inherit version src;
  pyproject = false;
  dontStrip = true;
  doCheck = true;
  patchFlags = [ "-p1" "--no-backup-if-mismatch" ];

  patches = [
    ../patches/store-copy-permissions.patch
    ../patches/nxm-handler-debug-logging.patch
    ../patches/nxm-launcher-service.patch
    ../patches/protontricks.patch
    ../patches/proton-wrapper-launcher-service.patch
  ];

  nativeBuildInputs = [
    python.pkgs.pyinstaller
    pkgs.makeWrapper
    pkgs.protontricks
  ];

  nativeCheckInputs = [ pkgs.protontricks ];

  dependencies = with python.pkgs; [
    certifi
    click
    inquirerpy
    loguru
    packaging
    patool
    pillow # needed by protontricks, which the handler bundles.
    psutil # imported by the nxm handler, which is bundled at build time
    pydantic-core # imported directly as pydantic_core; upstream's `pydantic` is not
    pyyaml
    requests
    send2trash
    vdf
    websockets
  ];

  makeWrapperArgs = [
    "--prefix"
    "PATH"
    ":"
    runtimeBinPath
  ];

  buildPhase = ''
    runHook preBuild

    ${python.interpreter} -c "import protontricks.cli.main" || {
      echo "protontricks is not importable from ${python.libPrefix}: the handler would be bundled broken" >&2
      exit 1
    }

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

    runHook postBuild
  '';

  pythonImportsCheck = [
    "certifi" "click" "InquirerPy" "loguru" "packaging" "patoolib" "PIL"
    "psutil" "pydantic_core" "requests" "send2trash" "vdf" "websockets" "yaml"
  ];

  checkPhase = ''
    runHook preCheck

    export PYTHONPATH="$PWD/src/mo2-lint:$PWD/src''${PYTHONPATH:+:$PYTHONPATH}"
    ${python.interpreter} -m unittest discover -s tests -v

    ${python.interpreter} - <<'PY'
    from importlib.metadata import version
    from packaging.version import Version
    minimums = {
        "certifi": "2026.7.22", "click": "8.4.2", "inquirerpy": "0.3.4",
        "loguru": "0.7.3", "patool": "4.0.5", "psutil": "7.1.3",
        "pyyaml": "6.0.3", "requests": "2.34.2", "send2trash": "2.0.0",
        "vdf": "3.4", "websockets": "17.0.1",
                              }
    for name, minimum in minimums.items():
        have = version(name)
        if Version(have) < Version(minimum):
            print(f"warning: {name} {have} is older than upstream's minimum {minimum}")
    PY

    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/mo2-lint $out/bin
    cp -r . $out/lib/mo2-lint
    # Build-only leftovers: PyInstaller's work directory (also holds the
    # tracked hooks, already baked into the handler), its spec file, and tests
    rm -rf $out/lib/mo2-lint/build $out/lib/mo2-lint/tests
    rm -f $out/lib/mo2-lint/*.spec
    cp -r "$out/lib/mo2-lint/src/steam-proton-wrapper" \
      "$out/lib/mo2-lint/steam-proton-wrapper"

    install -Dm755 \
      ${redirector}/mo2-redirector.exe \
      $out/lib/mo2-lint/dist/mo2-redirector.exe

    # The real handler stays in the store, wrapped with the runtime PATH.
    mkdir -p $out/libexec
    mv $out/lib/mo2-lint/dist/nxm-handler $out/libexec/nxm-handler-bin
    makeWrapper $out/libexec/nxm-handler-bin $out/bin/mo2-lint-nxm-handler \
      --prefix PATH : ${handlerBinPath}

    # Upstream's installer copies dist/nxm-handler into ~/.local/share/mo2-lint/.
    # Make that file a constant stub, so the home copy never goes stale.
    cat > $out/lib/mo2-lint/dist/nxm-handler <<'STUB'
    #!/bin/sh
    # Browsers start this with a minimal environment: find the wrapped handler.
    for d in "$HOME/.nix-profile/bin" \
             "''${XDG_STATE_HOME:-$HOME/.local/state}/nix/profile/bin" \
             "/etc/profiles/per-user/''${USER:-$(id -un 2>/dev/null)}/bin" \
             /run/current-system/sw/bin; do
      case ":$PATH:" in
        *":$d:"*) ;;
        *) PATH="$PATH:$d" ;;
      esac
    done
    export PATH
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
    #!${python.interpreter}
    import runpy
    import sys

    sys.path.insert(0, "$out/lib/mo2-lint/src/mo2-lint")
    sys.path.insert(0, "$out/lib/mo2-lint/src")
    runpy.run_path("$out/lib/mo2-lint/src/mo2-lint/__init__.py", run_name = "__main__")
    EOF
    chmod +x $out/bin/mo2-lint

    runHook postInstall
  '';

  meta = {
    description = "Mod Organizer 2 installer for Linux (MO2-LINT)";
    homepage = "https://github.com/Furglitch/modorganizer2-linux-installer";
    # Check upstream: gpl3Only vs gpl3Plus (see commands below).
    license = lib.licenses.gpl3Only;
    mainProgram = "mo2-lint";
    platforms = [ "x86_64-linux" ];
  };
}
