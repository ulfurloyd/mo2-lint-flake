# mo2-lint-flake

Nix Flake for [modorganizer2-linux-installer](https://github.com/Furglitch/modorganizer2-linux-installer)

### status

As of now, I've been able to run `mo2-lint install ...` to create a Skyrim Special Edition instance.
It runs all the way through and finishes successfully. This took _various_ workarounds I want to eventually get rid of.

Currently, the `Mod manager download` button on Nexus doesn't work,
but manual downloads work fine and are installable in MO2.
Tested with Skyrim SE and SkyUI.

### scope

The current flake targets x86_64-linux and uses Python 3.14 from nixpkgs.

### build & run

```bash
nix build .#mo2-redirector  # build the redirector
nix build .#mo2-lint        # build the application
./result/bin/mo2-lint
```

You can also run it directly with `nix run . -- <args>`.

### NixOS integration

Add the flake as an input in `flake.nix`:

```nix
{
  inputs = {
    mo2-lint = {
      url = "github:ulfurloyd/mo2-lint-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { mo2-lint, ... }: {
    nixosConfigurations.<hostname> = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ./configuration.nix
      ];
    };
  };
}
```

#### without the overlay

Add the package to `environment.systemPackages`:

```nix
{ inputs,  ... }: {
  environment.systemPackages = [
    inputs.mo2-lint.packages.${pkgs.system}.default
  ];
}
```

#### with the overlay

Apply the overlay in your configuration:

```nix
modules = [
  ({ ... }: {
    nixpkgs.overlays = [
      mo2-lint.overlays.default
    ];
  })
  ./configuration.nix
];
```

Then add the package in `configuration.nix`:

```nix
{ pkgs, ... }: {
  environment.systemPackages = [
    pkgs.mo2-lint
  ];
}
```

### home manager module

This flake provides a HM module to configure MO2-LINT's `settings.toml`.

#### configure settings

```nix
programs.mo2-lint = {
    enable = true;

    settings = {
        log_level = "info";
        check_updates = true;
        refresh_configs = true;
    };

    instance = {
        launcher = "steam";
        theme = "paper-dark";
        plugins = [
            "root-builder"
            "auto-activator"
        ];

        folders = {
            root_folder = "~/Games/mo2-lint";
            folder_name = "mo2-{game}-{launcher}";
        };
    };
};
```

### upstream

This repo packages upstream version 7.0.3 pinned to commit:
`7be2fe2359953c9cdbb99eb47a297ab3e8ec504b`.

> [!NOTE]
> Consider this nothing more than a proof of concept. there's a lot wrong with my
> (admittedly uninformed) approach. There's multiple "weird" substitutions during
> various build/patch phases. This is my first time really working with nix and
> flakes beyond my NixOS system flake. Regardless, as far as I can tell, this is the
> only attempt at creating a flake for `mo2-lint` so I do plan on getting it to
> a more reliable spot at the very least.
