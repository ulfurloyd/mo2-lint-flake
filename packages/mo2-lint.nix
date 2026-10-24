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

  postPatch = ''
    substituteInPlace src/mo2-lint/__init__.py \
      --replace-fail \
        '        copy2(tweaks_file, edit_file)' \
        '        edit_file.unlink(missing_ok=True)
            copy2(tweaks_file, edit_file)
            edit_file.chmod(0o644)'
    substituteInPlace src/nxm-handler/__init__.py \
      --replace-fail \
        '            cmdline = p.cmdline()' \
        '            cmdline = p.cmdline()
                if any("modorganizer.exe" in c.lower() for c in cmdline):
                    logger.debug(f"MO2 process candidate PID={p.pid}, cmdline={cmdline!r}")'
    substituteInPlace src/mo2-lint/util/nexus/install_handler.py \
      --replace-fail \
        '        copy2(internal_path, output)' \
        '        output.chmod(output.stat().st_mode | stat.S_IWUSR) if output.exists() else None
            copy2(internal_path, output)'
    substituteInPlace src/mo2-lint/util/redirector/install.py \
      --replace-fail \
        '    copy2(redirector_build, redirector_path)' \
        '    redirector_path.chmod(redirector_path.stat().st_mode | stat.S_IWUSR) if redirector_path.exists() else None
        copy2(redirector_build, redirector_path)'
    patch -p1 < ${../patches/protontricks.patch}
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
