#
# See `docs.md` for package documentation.
#
{
  system,
  lib, stdenv, fetchzip, fetchFromGitHub, fetchPypi,
  python3, rtlcss, wkhtmltopdf, wkhtmltopdf-bin
}:
let
  isLinux = stdenv.isLinux;
  ifLinux = ps: if isLinux then ps else [];
  is-x86_64 = lib.strings.hasPrefix "x86_64" system;

  pythonPackages = python3.pkgs;

  # Crea un ambiente virtuale con le dipendenze da pip
  pythonEnv = pythonPackages.buildPythonPackage {
    pname = "odoo16-deps";
    version = "1.0";
    format = "setuptools";

    src = ./.;  # Usa la directory corrente

    # Non eseguire i test delle dipendenze
    doCheck = false;

    # Specifica le dipendenze da pip
    propagatedBuildInputs = with pythonPackages; [
      pip
    ];

    # Installa le dipendenze da requirements.txt durante la fase di build
    buildInputs = [ pythonPackages.pip ];

    # Copia requirements.txt e installa le dipendenze
    postInstall = ''
      cp ${./requirements.txt} $out/requirements.txt
      export HOME=$TMPDIR
      cd $out
      ${pythonPackages.pip}/bin/pip install -r requirements.txt --prefix=$out
    '';
  };

  wkhtmltopdf-odoo =
    if is-x86_64
    then wkhtmltopdf-bin
    else import ./wkhtmltopdf.nix {
      inherit fetchFromGitHub wkhtmltopdf;
    };

in stdenv.mkDerivation rec {
  pname = "odoo16";
  series = "16.0";
  version = "${series}.20240214";

  src = fetchzip {
    url = "https://nightly.odoo.com/${series}/nightly/src/odoo_${version}.tar.gz";
    name = "${pname}-${version}";
    hash = "sha256-TVBYFEtCccBqdb1soXv/oydnK3nkwbKea+kAtE4h+wo=";
  };

  nativeBuildInputs = [
    python3
  ];

  buildInputs = [
    rtlcss
    pythonEnv
  ] ++ ifLinux [ wkhtmltopdf-odoo ];

  installPhase = ''
    mkdir -p $out/{bin,share/odoo}
    cp -r . $out/share/odoo
    
    cat > $out/bin/odoo <<EOF
    #!${stdenv.shell}
    PYTHONPATH=$out/share/odoo:${pythonEnv}/${python3.sitePackages}:$PYTHONPATH
    exec ${python3}/bin/python $out/share/odoo/odoo-bin "\$@"
    EOF
    chmod +x $out/bin/odoo
  '';

  meta = with lib; {
    description = "Open Source ERP and CRM";
    homepage = "https://www.odoo.com/";
    license = licenses.lgpl3Only;
  };
}
