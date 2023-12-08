# 1Password secrets management for NixOS

`opsm-nix` provides secrets management for NixOS using items from a 1Password vault.
It uses [1Password Service Accounts](https://developer.1password.com/docs/service-accounts)
to access the vault without the need for standing up additional infrastructure.

## Features

- Secret material stored out-of-band: configuration only has reference to the vault item
    - This also applies to the Nix store: it only contains the secret reference
- Provisioned to ramfs (by default in `/run/secrets`)
- systemd oneshot service created per-secret (similar to [NixOps](https://github.com/NixOS/nixops)),
  so other services that use the secret can require the service

## Usage

### Create a service account

First, create a 1Password Service Account, following the instructions outlined in
[1Password's documentation](https://developer.1password.com/docs/service-accounts/get-started).
You'll need to be the owner, administrator, or family manager of a 1Password account.

When creating the service account, you may choose what vaults it has access to.
You are encouraged to create a vault specifically for use with this tool,
and provide the account read access to this vault only.

1Password will generate a token for this service account.
Save it to your 1Password account, then copy it to `/etc/opsm-token` in each of the machines
in which you intend to use this module.

### Add to your configuration

This repository is a flake, and it exposes its NixOS module under `outputs.nixosModules.default`.
Add it to your flake of NixOS configurations via the `modules` argument:

```nix
{
  nixosConfigurations.example = nixpkgs.lib.nixosSystem {
    modules = [inputs.opsm-nix.nixosModules.default ...];
    # ...
  };
}
```

Then, in your configuration, enable the module and add your secrets, referring to them using
[secret references](https://developer.1password.com/docs/cli/secret-references/).

```nix
{
  opsm = {
    enable = true;
    # Add your secrets here
    secrets.example.secretRef = "op://vault/item/field";
    secrets.full-example = {
      secretRef = "op://vault/another item/field";
      user = "user";        # default is root
      group = "group";      # default is root
      mode = "0440";        # default is 0400
    };
  };
}
```

By default, secrets are refereshed every hour, but this can be changed with `opsm.refreshInterval`.
If `null`, each secret is only refreshed when its systemd service is restarted.
1Password imposes [quotas](https://developer.1password.com/docs/service-accounts/get-started/#request-quotas) on the amount of requests made in a 24-hour period,
so keep this in mind when provisioning a large amount of secrets.

These secrets are also conditioned on the file `/etc/opsm-token` existing.
If this file is not present, systemd will skip over each of these services.
