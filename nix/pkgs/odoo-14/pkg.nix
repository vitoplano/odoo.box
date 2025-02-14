#
# See `docs.md` for package documentation.
#
{
  system,
  lib, stdenv, fetchzip, fetchFromGitHub,
  python3, rtlcss, wkhtmltopdf, wkhtmltopdf-bin
}:
let
  isLinux = stdenv.isLinux;
  ifLinux = ps: if isLinux then ps else [];
  is-x86_64 = lib.strings.hasPrefix "x86_64" system;

  # Crea l'ambiente Python leggendo direttamente da requirements.txt
  pythonEnv = python3.withPackages (ps: 
    let
      # Legge il requirements.txt
      requirements = builtins.readFile ./requirements.txt;
      # Split in linee e rimuovi commenti
      lines = lib.filter (l: l != "" && ! lib.hasPrefix "#" l) 
        (lib.splitString "\n" requirements);
      # Funzione per estrarre il nome del pacchetto
      getName = requirement:
        let
          # Rimuovi eventuali vincoli di versione e condizioni
          base = lib.head (lib.splitString ";" requirement);
          name = lib.head (lib.splitString "==" base);
          nameCleaned = lib.head (lib.splitString ">=" name);
        in lib.toLower (lib.removeSuffix " " (lib.removePrefix " " nameCleaned));
      # Converti nomi pacchetti in riferimenti a pythonPackages
      getPackage = name:
        let 
          attr = if builtins.hasAttr name ps 
                 then name 
                 else throw "Python package ${name} not found";
        in ps.${attr};
    in
      map (name: getPackage name) (map getName lines)
  );

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
  ] ++ ifLinux [ wkhtmltopdf-odoo ];

  installPhase = ''
    mkdir -p $out/{bin,share/odoo}
    cp -r . $out/share/odoo
    
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
