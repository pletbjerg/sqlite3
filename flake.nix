{
  description = "A flake for SQLite3";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs }: 
  let pkgs = import nixpkgs { system = "x86_64-linux"; };
      version = "3.40.00";
      year = "2022";
      serialisedVersion = versionToSerialisedVersion version;
      # `versionToSerialisedVersion` converts a version string of the form
      # `X.YY.ZZ` to `XYYZZ00` which seems to be compatible with the URIs
      # in `https://www.sqlite.org/download.html`.
      versionToSerialisedVersion = version: 
        builtins.concatStringsSep "" (builtins.match ''([0-9]).([0-9][0-9]).([0-9][0-9])'' version) + "00";

      # See `https://www.sqlite.org/download.html` for downloads.
      # Grab the source code / its corresponding directory
      fetchSqliteAutoconf = builtins.fetchurl {
        url = "https://www.sqlite.org/${year}/sqlite-autoconf-${serialisedVersion}.tar.gz";
        sha256 = "1rw0i63822pdkb3a16sqj4jdcp5zg0ffjmi26mshqw6jfqh5acq3";
      };
      sqliteSrcDir = "sqlite-autoconf-${serialisedVersion}";
      # Grab the documentation / its corresponding directory
      fetchSqliteDoc = builtins.fetchurl {
        url = "https://www.sqlite.org/${year}/sqlite-doc-${serialisedVersion}.zip";
        sha256 = "1bcdy1179r46bpvyfy9plhjfy2nr9zdd1mcp6n8n62cj3vvidp0s";
      };
      sqliteDocDir = "sqlite-doc-${serialisedVersion}";

      # 
      sqliteDocHelp
      
  in rec {
    packages.x86_64-linux.default = pkgs.stdenv.mkDerivation {
        pname = "sqlite3";
        inherit version;

        srcs = [ fetchSqliteAutoconf fetchSqliteDoc ];
        sourceRoot = "./.";

        outputs = [ "out" ];

        nativeBuildInputs = 
            [ 
                # `readline` makes the CLI interface usable
                pkgs.readline 
                # `unzip` is needed for grabbing the HTML docs
                pkgs.unzip 
            ];

        # Modifying the phases.
        # See [nixpkgs documentation](https://nixos.org/manual/nixpkgs/stable/#sec-using-stdenv)
        # See
        # [stdenv](https://github.com/NixOS/nixpkgs/blob/master/pkgs/stdenv/generic/setup.sh)
        # implementation as well.
        # Debugging notes:
        #   - Enter `nix develop`
        #   - Run `genericBuild`
        unpackPhase = ''
            runHook preUnpack

            tar -xvf ${fetchSqliteAutoconf}
            unzip ${fetchSqliteDoc}

            runHook postUnpack
        '';

        configurePhase = ''
            runHook preConfigure

            pushd ${sqliteSrcDir}
            ./configure             \
                --prefix=$out       \
                --enable-readline   \
                --enable-threadsafe \
                --enable-math       \
                --enable-fts4       \
                --enable-fts5
            popd

            runHook postConfigure
        '';

        buildPhase = ''
            runHook preBuild

            pushd ${sqliteSrcDir}
            make
            popd

            runHook postBuild
        '';

        installPhase = ''
            runHook preInstall

            # Install sqlite
            echo "Installing sqlite..."
            pushd ${sqliteSrcDir}
            make install
            popd

            # Install the doc
            echo "Installing sqlite documentation..."
            pushd ${sqliteDocDir}
            cp -r . "$out/share/doc"
            popd

            # TODO add easy way to open up help documentation.

            runHook postInstall
        '';
    };

    devShells.x86_64-linux.default = packages.x86_64-linux.default;
  };
}
