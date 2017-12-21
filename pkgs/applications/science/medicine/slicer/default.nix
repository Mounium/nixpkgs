{ stdenv, fetchurl, rpmextract, makeWrapper, patchelf, qt4, zlib, libX11, libXt, libSM, libICE, libXext, mesa, libXrender, fontconfig, freetype, glib }:

with stdenv.lib;
stdenv.mkDerivation {
  name = "slicer";
  src = fetchurl {
    url = "http://download.slicer.org/bitstream/733693";
    sha256 = "1m5dpgl98dvg70dp494cv1v8gd2q72igixkw4a8i3455xd7wf2sy";
    name = "slicer.tar.gz";
  };

  buildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    mkdir -p $out
    cp -r bin include lib libexec share Slicer $out

    runHook postInstall
  '';

  postInstall = let
    libs = stdenv.lib.makeLibraryPath [ qt4 zlib stdenv.cc.cc libSM libICE libX11 libXext libXt mesa libXrender fontconfig freetype glib ];
  in ''
    for i in bin/* Slicer
    do
      if ${patchelf}/bin/patchelf \
        --interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" \
        $out/$i
      then :
    fi
    done

    wrapProgram $out/Slicer \
      --prefix LD_LIBRARY_PATH : ${libs}

    echo "#!/bin/bash
    $out/Slicer" > $out/bin/slicer
    chmod +x $out/bin/slicer
  '';

  meta = {
    description = "A software platform for the analysis and visualization  of medical images and for research in image guided therapy.";
    homepage = https://www.slicer.org;
    maintainers = with maintainers; [ mounium ];
  };
}
