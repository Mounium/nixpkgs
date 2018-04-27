{ stdenv, fetchFromGitHub, python, pythonPackages }:

stdenv.mkDerivation rec {
  name = "zeronet-${version}";
  version = "0.6.2";

  src = fetchFromGitHub {
    owner = "HelloZeroNet";
    repo = "ZeroNet";
    rev = "fd8e1ed623cdfdfba462ca6f300558638eb160f1";
    sha256 = "0l1z9dmhxis75s84jp5llc2j194lf9qls1ywi3r5pn5418gdndi5";
  };

  patchPhase = ''
    sed -i -e '83s|.*|        elif this_file.startswith("/nix"):|' src/Config.py
  '';

  installPhase =  let
    libs = with pythonPackages; stdenv.lib.makeSearchPath "lib/python2.7/site-packages" [ gevent msgpack greenlet ];
  in
  ''
    mkdir -p $out/bin $out/share/zeronet

    mv start.py zeronet.py src plugins tools $out/share/zeronet
    cat <<EOF > $out/bin/zeronet
    #!/bin/sh
    if [ ! -d ~/ZeroNet ]; then
      mkdir ~/ZeroNet
    fi
    PYTHONPATH=${libs} ${python}/bin/python $out/share/zeronet/zeronet.py
    EOF

    chmod +x $out/bin/zeronet
  '';
}
