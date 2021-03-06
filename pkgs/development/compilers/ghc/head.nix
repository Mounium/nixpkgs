{ stdenv, targetPackages
, buildPlatform, hostPlatform, targetPlatform
, selfPkgs, cross ? null

# build-tools
, bootPkgs, alex, happy
, autoconf, automake, coreutils, fetchgit, perl, python3

, libiconv ? null, ncurses

, # If enabled, GHC will be built with the GPL-free but slower integer-simple
  # library instead of the faster but GPLed integer-gmp library.
  enableIntegerSimple ? false, gmp ? null

, version ? "8.5.20171209"
}:

assert !enableIntegerSimple -> gmp != null;

let
  inherit (bootPkgs) ghc;

  rev = "4335c07ca7e64624819b22644d7591853826bd75";

  # TODO(@Ericson2314) Make unconditional
  targetPrefix = stdenv.lib.optionalString
    (targetPlatform != hostPlatform)
    "${targetPlatform.config}-";
in
stdenv.mkDerivation (rec {
  inherit version rev;
  name = "ghc-${version}";

  src = fetchgit {
    url = "git://git.haskell.org/ghc.git";
    inherit rev;
    sha256 = "19csad94sk0bw2nj97ppmnwh4c193jg0jmg5w2sx9rqm9ih4yg85";
  };

  postPatch = "patchShebangs .";

  preConfigure = ''
    echo ${version} >VERSION
    echo ${rev} >GIT_COMMIT_ID
    ./boot
    sed -i -e 's|-isysroot /Developer/SDKs/MacOSX10.5.sdk||' configure
  '' + stdenv.lib.optionalString (!stdenv.isDarwin) ''
    export NIX_LDFLAGS="$NIX_LDFLAGS -rpath $out/lib/ghc-${version}"
  '' + stdenv.lib.optionalString stdenv.isDarwin ''
    export NIX_LDFLAGS+=" -no_dtrace_dof"
  '' + stdenv.lib.optionalString enableIntegerSimple ''
    echo "INTEGER_LIBRARY=integer-simple" > mk/build.mk
  '' + stdenv.lib.optionalString (targetPlatform != hostPlatform) ''
    sed 's|#BuildFlavour  = quick-cross|BuildFlavour  = perf-cross|' mk/build.mk.sample > mk/build.mk
  '';

  buildInputs = [ ghc perl autoconf automake happy alex python3 ];

  enableParallelBuilding = true;

  configureFlags = [
    "CC=${stdenv.cc}/bin/cc"
    "--with-curses-includes=${ncurses.dev}/include" "--with-curses-libraries=${ncurses.out}/lib"
    "--datadir=$doc/share/doc/ghc"
  ] ++ stdenv.lib.optional (! enableIntegerSimple) [
    "--with-gmp-includes=${gmp.dev}/include" "--with-gmp-libraries=${gmp.out}/lib"
  ] ++ stdenv.lib.optional stdenv.isDarwin [
    "--with-iconv-includes=${libiconv}/include" "--with-iconv-libraries=${libiconv}/lib"
  ];

  # required, because otherwise all symbols from HSffi.o are stripped, and
  # that in turn causes GHCi to abort
  stripDebugFlags = [ "-S" ] ++ stdenv.lib.optional (!targetPlatform.isDarwin) "--keep-file-symbols";

  checkTarget = "test";

  postInstall = ''
    paxmark m $out/lib/${name}/bin/${if targetPlatform != hostPlatform then "ghc" else "{ghc,haddock}"}

    # Install the bash completion file.
    install -D -m 444 utils/completion/ghc.bash $out/share/bash-completion/completions/${targetPrefix}ghc

    # Patch scripts to include "readelf" and "cat" in $PATH.
    for i in "$out/bin/"*; do
      test ! -h $i || continue
      egrep --quiet '^#!' <(head -n 1 $i) || continue
      sed -i -e '2i export PATH="$PATH:${stdenv.lib.makeBinPath [ targetPackages.stdenv.cc.bintools coreutils ]}"' $i
    done
  '';

  outputs = [ "out" "doc" ];

  passthru = {
    inherit bootPkgs targetPrefix;
  } // stdenv.lib.optionalAttrs (targetPlatform != buildPlatform) {
    crossCompiler = selfPkgs.ghc.override {
      cross = targetPlatform;
      bootPkgs = selfPkgs;
    };
  };

  meta = {
    homepage = http://haskell.org/ghc;
    description = "The Glasgow Haskell Compiler";
    maintainers = with stdenv.lib.maintainers; [ marcweber andres peti ];
    inherit (ghc.meta) license platforms;
  };

} // stdenv.lib.optionalAttrs (cross != null) {
  name = "${cross.config}-ghc-${version}";

  configureFlags = [
    "CC=${stdenv.cc}/bin/${cross.config}-cc"
    "LD=${stdenv.cc.bintools}/bin/${cross.config}-ld"
    "AR=${stdenv.cc.bintools}/bin/${cross.config}-ar"
    "NM=${stdenv.cc.bintools}/bin/${cross.config}-nm"
    "RANLIB=${stdenv.cc.bintools}/bin/${cross.config}-ranlib"
    "--target=${cross.config}"
    "--enable-bootstrap-with-devel-snapshot"
  ] ++
    # fix for iOS: https://www.reddit.com/r/haskell/comments/4ttdz1/building_an_osxi386_to_iosarm64_cross_compiler/d5qvd67/
    stdenv.lib.optional (cross.config or null == "aarch64-apple-darwin14") "--disable-large-address-space";

  configurePlatforms = [];

  passthru = {
    inherit bootPkgs cross;
    cc = "${stdenv.cc}/bin/${cross.config}-cc";
    ld = "${stdenv.cc}/bin/${cross.config}-ld";
  };
})
