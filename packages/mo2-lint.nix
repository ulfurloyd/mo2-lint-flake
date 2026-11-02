{
  lib,
  pkgs,
  python,
  src,
  version,
  redirector,
}:
let
  runtimeBinPath = lib.makeBinPath (
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

  # PyInstaller bundles protontricks from the store, so it must be built for
  # the same Python as the handler.
  protontricksSite = "${pkgs.protontricks}/${python.sitePackages}";
in
python.pkgs.buildPythonApplication {
  pname = "mo2-lint";
  inherit version src;
  pyproject = false;
  dontStrip = true;
  doCheck = true;

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
  ];

  nativeCheckInputs = [ pkgs.protontricks ];

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

  buildPhase = ''
    runHook preBuild

    test -d "${protontricksSite}" || {
      echo "protontricks is not built for ${python.libPrefix}; PyInstaller would miss it" >&2
      exit 1
    }

    pyinstaller --clean --noconfirm --onefile \
      --name nxm-handler \
      --paths src \
      --paths ${protontricksSite} \
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

  checkPhase = ''
    runHook preCheck

    export PYTHONPATH="$PWD/src/mo2-lint:$PWD/src''${PYTHONPATH:+:$PYTHONPATH}"
    ${python.interpreter} -m unittest discover -s tests -v

    runHook postCheck
  '';

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/mo2-lint $out/bin
    cp -r . $out/lib/mo2-lint
    cp -r "$out/lib/mo2-lint/src/steam-proton-wrapper" \
      "$out/lib/mo2-lint/steam-proton-wrapper"

    install -Dm755 \
      ${redirector}/mo2-redirector.exe \
      $out/lib/mo2-lint/dist/mo2-redirector.exe

    # The real handler stays in the store, wrapped with the runtime PATH.
    mkdir -p $out/libexec
    mv $out/lib/mo2-lint/dist/nxm-handler $out/libexec/nxm-handler-bin
    makeWrapper $out/libexec/nxm-handler-bin $out/bin/mo2-lint-nxm-handler \
      --prefix PATH : ${runtimeBinPath}

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

  # pyproject = false skips the runtime-deps check, so verify imports by hand.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    ${python.interpreter} - <<'PY'
    import certifi, click, InquirerPy, loguru, packaging, patoolib, PIL
    import psutil, pydantic_core, requests, send2trash, vdf, websockets, yaml
    PY
    runHook postInstallCheck
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
