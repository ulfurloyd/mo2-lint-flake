# Third-Party Notices

## Mod Organizer 2 Linux Installer

This project packages and builds components from the upstream
[modorganizer2-linux-installer](https://github.com/Furglitch/modorganizer2-linux-installer)
project.

- **Upstream repository:** https://github.com/Furglitch/modorganizer2-linux-installer
- **Pinned revision:** `7be2fe2359953c9cdbb99eb47a297ab3e8ec504b`
- **Upstream license:** GNU General Public License v3.0 (GPL-3.0)

The upstream license text is preserved in [`source/LICENSE`](source/LICENSE).
The root [`LICENSE`](LICENSE) also contains the GPL-3.0 license text.

### Windows redirector executable

The bundled `assets/mo2-redirector.exe` is a build artifact generated from the upstream redirector implementation in `src/redirector/__init__.py`.

It was built using Windows Python 3.13 under Wine with PyInstaller. The build includes the upstream configuration and shared source files, as specified by the upstream Makefile's `redirector` target.

The executable is derived from upstream source; it is not an independently implemented replacement. Its distribution is subject to the applicable upstream licensing terms.

## Scope of this project

This repository provides Nix packaging and integration for the upstream project. Its packaging expressions, local patches, build configuration, and documentation should be distinguished from upstream source files and bundled third-party components.

Consult each component's own license and notices for additional terms that may apply.
