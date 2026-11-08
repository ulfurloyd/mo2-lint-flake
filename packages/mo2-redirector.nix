{
  lib,
  pkgs,
  src,
  version,
  ...
}:
let
  redirectorPython = pkgs.fetchurl {
    url = "https://www.python.org/ftp/python/3.13.0/python-3.13.0-embed-amd64.zip";
    hash = "sha256-AcMtBzdDIkCtzwu8HTIyfwl206HhQnd0vI/ryPHAMRE=";
  };

  redirectorWheels = [
    (pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/24/83/c5422204772a27aef643280fdc887b7ef55679989096b21dceb1b9625fc4/pyinstaller-6.22.3-py3-none-win_amd64.whl";
      hash = "sha256-UAvVjHv35YSoQ1rcy9djoLkY1cErCNdP9Q/XmykVRYs=";
    })
    (pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/93/fe/ded0e20de0580257d97dbabb4db7ab4d96ad8ade7d41149e66308057cf52/pyinstaller_hooks_contrib-2026.9-py3-none-any.whl";
      hash = "sha256-+z5n3WQSJWFyTEitA2asnowW5ji2O/fYXeA78/2/BsM=";
    })
    (pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/a9/ba/000a1996d4308bc65120167c21241a3b205464a2e0b58deda26ae8ac21d1/altgraph-0.17.5-py2.py3-none-any.whl";
      hash = "sha256-86IkALzhsMcBaDggrE87FZzTAayrBnxRxlPgaWFgBZc=";
    })
    (pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/63/34/ba1c580383c9eada3711951fef0795c80b829a078d72188184bcab9dd527/packaging-26.3-py3-none-any.whl";
      hash = "sha256-1xk/fI5Ok/RE/eAmK/kK8w4W+grQrUTLVTyHM5sjzRw=";
    })
    (pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/54/16/12b82f791c7f50ddec566873d5bdd245baa1491bac11d15ffb98aecc8f8b/pefile-2024.8.26-py3-none-any.whl";
      hash = "sha256-dvi0hdzTsbuBZvESjTlfo9h68mNgwjWPt1uAAZuVfG8=";
    })
    (pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/de/3d/8161f7711c017e01ac9f008dfddd9410dff3674334c233bde66e7ba65bbf/pywin32_ctypes-0.2.3-py3-none-any.whl";
      hash = "sha256-ihUTN51wmXVVLSAtlC2YN3WJBcjQHrgri8wwkYkp57g=";
    })
    (pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/18/02/b4bbb90f8f29e334898ff45c6d9b1fffaa6f378017052b3023a06262b5f7/setuptools-84.1.0-py3-none-any.whl";
      hash = "sha256-UjFonGrIFWzRVc+5jD/W+yUsPn6b09eLZNPFXxMmJMk=";
    })
    (pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/97/c9/39d5b874e8b28845e4ec2202b5da735d0199dbe5b8fb85f91398814a9a46/pyyaml-6.0.3-cp313-cp313-win_amd64.whl";
      hash = "sha256-eQBaDZfV3av+7qTPZ2rxHmR+QdgcmncioZMCKszba3w=";
    })
    (pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/0c/29/0348de65b8cc732daa3e33e67806420b2ae89bdce2b04af740289c5c6c8c/loguru-0.7.3-py3-none-any.whl";
      hash = "sha256-MaM8EMjh4QQiv9QxrrXTUcfPf6Zx48TfAEFiJksoIgw=";
    })
    (pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/d1/d6/3965ed04c63042e047cb6a3e6ed1a63a35087b6a609aa3a15ed8ac56c221/colorama-0.4.6-py2.py3-none-any.whl";
      hash = "sha256-Tx2ZkfWswMoRn51ENiC3f51rM3A+UQEcFrr1evsoX8Y=";
    })
    (pkgs.fetchurl {
      url = "https://files.pythonhosted.org/packages/e1/07/c6fe3ad3e685340704d314d765b7912993bcb8dc198f0e7a89382d37974b/win32_setctime-1.2.0-py3-none-any.whl";
      hash = "sha256-ldZExOcIq6gdw3BKEW2MvJdNcLO9uL4dFQ42vm6dE5A=";
    })
  ];
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "mo2-redirector";
  inherit version src;

  nativeBuildInputs = [
    pkgs.wineWow64Packages.stable
    pkgs.unzip
  ];

  dontConfigure = true;
  dontFixup = true;

  patches = [
    ../patches/redirector-game-path.patch
  ];

  buildPhase = ''
    runHook preBuild

    export HOME="$TMPDIR/home"
    export WINEPREFIX="$TMPDIR/wineprefix"
    export WINEARCH=win64
    export WINEDEBUG=-all
    export WINEDLLOVERRIDES="mscoree,mshtml="     # never try to fetch Mono or Gecko
    export PYTHONHASHSEED=1                       # fixes hash-based ordering
    mkdir -p "$HOME"

    mkdir -p "$TMPDIR/python/Lib/site-packages"
    unzip -q ${redirectorPython} -d "$TMPDIR/python"

    cat > "$TMPDIR/python/python313._pth" <<'PTH'
    python313.zip
    .
    Lib\site-packages
    import site
    PTH

    for wheel in ${pkgs.lib.concatStringsSep " " (map toString redirectorWheels)}; do
      unzip -oq "$wheel" -d "$TMPDIR/python/Lib/site-packages"
    done

    wineboot -u

    wine "$TMPDIR/python/python.exe" -m PyInstaller \
      --clean \
      --noconfirm \
      --onefile \
      --noconsole \
      --name mo2-redirector.exe \
      --paths src \
      --hidden-import loguru \
      --hidden-import yaml \
      --hidden-import configparser \
      --add-data 'configs;cfg' \
      --add-data 'src/shared;src/shared' \
      --icon .github/README/logo.ico \
      src/redirector/__init__.py

    test -s dist/mo2-redirector.exe

    # Stop the wineserver started by this build before the sandbox goes away.
    wineserver -k || true

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    install -Dm755 dist/mo2-redirector.exe \
      "$out/mo2-redirector.exe"
    runHook postInstall
  '';

  meta = {
    description = "Windows launcher redirector for MO2-LINT (built under Wine)";
    license = lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
