#
# See `docs.md` for package documentation.
#
{
  system,
  lib, stdenv, fetchzip, fetchFromGitHub,
  python3,rtlcss, wkhtmltopdf, wkhtmltopdf-bin
}:
let
  isLinux = stdenv.isLinux;
  ifLinux = ps: if isLinux then ps else [];
  is-x86_64 = lib.strings.hasPrefix "x86_64" system;

  pythonPackages = python3.pkgs;
  requirements = builtins.fromJSON (builtins.readFile ./requirements.hashes.json);

  mkPythonPackage = packageInfo: 
    pythonPackages.buildPythonPackage {
      pname = packageInfo.name;
      version = packageInfo.version;
      src = pythonPackages.fetchPypi {
        pname = packageInfo.name;
        version = packageInfo.version;
        hash = builtins.head packageInfo.hashes;
      };
      doCheck = false;
    };

  pythonDeps = map mkPythonPackage requirements.packages;

  wkhtmltopdf-odoo =
    if is-x86_64
    then wkhtmltopdf-bin
    else import ./wkhtmltopdf.nix {
      inherit fetchFromGitHub wkhtmltopdf;
    };                                                         # (1)
in stdenv.mkDerivation rec {
  pname = "odoo16";
  series = "16.0";
  version = "${series}.20221012";

  src = fetchzip {
    url = "https://nightly.odoo.com/${series}/nightly/src/odoo_${version}.tar.gz";
    name = "${pname}-${version}";
    hash = "sha256-TVBYFEtCccBqdb1soXv/oydnK3nkwbKea+kAtE4h+wo=";
  };                                                           # (2)

  nativeBuildInputs = [
    python3
  ];

  patches = [
    ./server.py.patch                                          # (3)
  ];
  
  buildInputs = [
    rtlcss
  ] ++ ifLinux [ wkhtmltopdf-odoo ];

  pythonEnv = python3.withPackages (ps: pythonDeps);

  installPhase = ''
    mkdir -p $out/{bin,share/odoo}
    cp -r . $out/share/odoo
    
    # Crea lo script wrapper
    cat > $out/bin/odoo <<EOF
    #!${stdenv.shell}
    PYTHONPATH=$out/share/odoo:$PYTHONPATH
    exec ${pythonEnv}/bin/python $out/share/odoo/odoo-bin "\$@"
    EOF
    chmod +x $out/bin/odoo
  '';


  meta = with lib; {
    description = "Open Source ERP and CRM";
    homepage = "https://www.odoo.com/";
    license = licenses.lgpl3Only;
  };
}
# NOTE
# ----
# 1. wkhtmltopdf. See (1) in `wkhtmltopdf.nix` for the version we compile
# as well as
# - https://github.com/c0c0n3/odoo.box/issues/23
# for the issues we're having at the moment. Notice `wkhtmltopdf-bin`
# contains a binary fetched from the interwebs which was compiled for
# Arch Linux and includes the `wkhtmltopdf` patched version of Qt. Not
# optimal, but it works on x86 machines.
#
# 2. Source. Why not fetch from GitHub? Because the tarball consolidates
# all the add-ons in the `odoo/addons` dir whereas the repo has them split
# in two dirs: `repo/addons` and `repo/odoo/addons`. If you run the server
# from the repo you'll have to pass the path to the other addons dir since
# some of the modules the code in `repo/odoo` expects are actually in the
# `repo/addons` dir.
#
# 3. Gevent server. We've got to patch the source to fix an issue with
# the gevent server Odoo uses for long-polling/chat. The problem is that
# the code to spawn the server blindly assumes the command line to start
# Odoo was in the format `python odoo ...`, but this may not be true in
# general since a quite common thing to do is to actually use a shell start
# script. The problem boils down to line 713 in `odoo/service/server.py`
# where `long_polling_spawn` starts the gevent process with this command:
#
#     cmd = [sys.executable, sys.argv[0], 'gevent'] + nargs[1:]
#
# So if you used a start script `my-odoo`, Odoo would try running a
# command like `python my-odoo ...` which would fail unless `my-odoo`
# is Python code. This is exactly the case for our Nix package where
# a shell script called `odoo` nicely sets up the server env before
# actually invoking Python on yet another Nix wrapper script, called
# `.odoo-wrapped`, which is a Python script that sets up the Python
# lib path before finally calling `odoo.cli.main`. Long story short,
# changing the Python line above into the one below makes Odoo start
# cleanly and spawn the gevent process as expected.
#
#     cmd = [sys.argv[0], 'gevent'] + nargs[1:]
#
# See `server.py.patch`.
#
# 4. Broken tests. Some tests are broken, so we've got to skip testing.
#
# 5.Stripping. The Odoo 15 package skips stripping, claiming it takes 5+
# minutes and there are no files to strip. So we do the same.
#
