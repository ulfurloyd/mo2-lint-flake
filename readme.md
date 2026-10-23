# mo2-lint-flake

Nix Flake for [modorganizer2-linux-installer](https://github.com/Furglitch/modorganizer2-linux-installer)

### status

As of now, I've been able to run `mo2-lint install ...` to create a Skyrim Special Edition instance.
It runs all the way through and finishes successfully. This took _various_ workarounds I want to eventually get rid of.

Currently, the `Mod manager download` button on Nexus doesn't work,
but manual downloads work fine and are installable in MO2.
Tested with Skyrim SE and SkyUI.

> [!NOTE]
> Consider this nothing more than a proof of concept. there's a lot wrong with my
> (admittedly uninformed) approach. There's multiple "weird" substitutions during
> various build/patch phases, and I did not build the redirector in the flake.
> This is my first time really working with nix and flakes beyond my NixOS system flake.
> Regardless, as far as I can tell, this is the only attempt at creating a flake for
> `mo2-lint` so I do plan on getting it to a more reliable spot at the very least.
