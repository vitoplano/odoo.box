NixOS Deployment
----------------
> Nix's GitOps' best buddy!

NixOS naturally lends itself to a GitOps approach. You keep the Nix
expressions that define your NixOS deployment in a git repo and then
simply apply them to a remote set of machines to make Nix update
their configuration, packages, services, etc. The git repo is the
single source of truth, the remote machines reflect the deployment
state declared in the repo.


### Remote deployment worked example

Let's go through a concrete example of how to apply a Nix config
in a git repo to a remote NixOS machine. We're going to show how
to update the NixOS system we built on Qemu during the bootstrap
procedure using a Nix Flake sitting **outside** of that machine.

The `nix/nodes/devm-aarch64` folder contains the following files

* `hardware-configuration.nix`. The result of the hardware scan
  Nix did before installing NixOS on our Qemu VM. Basically we
  copied out the content of `/etc/nixos/hardware-configuration.nix`
  in the VM. We do this because we want to keep all the Nix
  expressions that define the system in source control.
* `configuration.nix`. Core system configuration. It declares
  the same one-node K8s cluster we built during the bootstrap
  procedure.

Our Flake defines a `demv` output to wrap the above NixOS config
and make sure we get full reproducibility.

So the **whole** NixOS system definition sits in our git repo and
now we can apply it to **any** machine running NixOS. We do this
by asking `nixos-rebuild` to build our `flake.nix` file on
a remote machine we choose. Under the bonnet Nix logs on to that
machine through SSH, builds the NixOS system declared in `flake.nix`
and then replaces the current NixOS system on the remote machine
with the one built from `flake.nix`. (Read more about it in [this
excellent blog post][nix-depl].)

Since we've already built a Qemu dev VM earlier during the bootstrap
procedure, let's apply `flake.nix` to it. First off, start the VM
as explained in the bootstrap procedure. Basically start our Nix
shell and then run the start script:

```bash
$ cd odoo.box/nix
$ nix shell
$ cd where/you/put/the/vm
$ ./start.sh
```

Now open another terminal and start the Nix shell

```bash
$ cd odoo.box/nix
$ nix shell
```

Our Nix shell contains the `nixos-rebuild` tool we need to run. We
ask `nixos-rebuild` to build the `devm` NixOS expression in `flake.nix`
on the machine at `locahost` with SSH access on port 22—i.e. our
Qemu VM. Here's what it looks like

```bash
$ nixos-rebuild switch --fast --flake .#devm \
    --target-host root@localhost --build-host root@localhost

# Enter the VM's root password when prompted—unless you changed the
# default config, the password is `abc123`.
```

Notice if you've configured the dev VM to use SSH keys, you could
run something like

```bash
$ NIX_SSHOPTS='-i path/to/id_ed25519' \
  nixos-rebuild switch --fast --flake .#devm \
    --target-host root@localhost --build-host root@localhost
```

instead to avoid the password prompt.

Either way, now the Qemu VM runs the NixOS system declared in the
local `flake.nix` file. Sweet!


### Upping our game

While `nixos-rebuild` already goes a long way, there's other tools
we could leverage to manage a cloud of NixOS machines:

- [nixos-anywhere][nixos-anywhere]
- [NixOps][nixops]
- [Colmena][colmena]
- [morph][morph]

These tools can be a life-saver for complex cloud deployments with
dozens of machines where you want everything automated, audited and
fully reproducible. But if you only have a couple of machines to
manage, `nixos-rebuild` is probably the best option.




[colmena]: https://github.com/zhaofengli/colmena
[morph]: https://github.com/DBCDK/morph
[nix-depl]: https://www.haskellforall.com/2023/01/announcing-nixos-rebuild-new-deployment.html
[nixops]: https://github.com/NixOS/nixops
[nixos-anywhere]: https://github.com/numtide/nixos-anywhere
