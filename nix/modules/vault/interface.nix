#
# See `docs.md` for module documentation.
#
{ config, lib, pkgs, ... }:

with lib;
with types;

{
  options = {
    odbox.vault.root-pwd-file = mkOption {
      type = path;
      default = abort "missing root password!";
      description = ''
        File containing the root user's password hashed in a way `chpasswd`
        can handle.
      '';
    };
    odbox.vault.root-ssh-file = mkOption {
      type = nullOr path;
      default = null;
      description = ''
        File containing the root user's SSH public key. If specified the
        key gets added to the authorised SSH keys so the user can log in
        through SSH with their private key instead of using a password.
      '';
    };
    odbox.vault.admin-pwd-file = mkOption {
      type = path;
      default = abort "missing admin password!";
      description = ''
        File containing the admin user's password hashed in a way `chpasswd`
        can handle.
      '';
    };
    odbox.vault.admin-ssh-file = mkOption {
      type = nullOr path;
      default = null;
      description = ''
        File containing the admin user's SSH public key. If specified the
        key gets added to the authorised SSH keys so the user can log in
        through SSH with their private key instead of using a password.
      '';
    };
    odbox.vault.odoo-admin-pwd-file = mkOption {
      type = path;
      default = abort "missing Odoo admin password!";
      description = ''
        File containing the Odoo admin user's clear-text password.
      '';
    };
    odbox.vault.nginx-cert = mkOption {
      type = path;
      default = abort "missing Nginx's TLS certificate!";
      description = "Path to the Nginx's TLS certificate.";
    };
    odbox.vault.nginx-cert-key = mkOption {
      type = path;
      default = abort "missing Nginx's TLS certificate key! ";
      description = "Path to the Nginx's TLS certificate key.";
    };
  };
}
