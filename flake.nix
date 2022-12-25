{
  description = "A flake for SQLite3";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
  };

  outputs = { self, nixpkgs }: 
  let system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
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
      fetchSqlite3Autoconf = builtins.fetchurl {
        url = "https://www.sqlite.org/${year}/sqlite-autoconf-${serialisedVersion}.tar.gz";
        sha256 = "1rw0i63822pdkb3a16sqj4jdcp5zg0ffjmi26mshqw6jfqh5acq3";
      };
      sqlite3SrcDir = "sqlite-autoconf-${serialisedVersion}";
      # Grab the documentation / its corresponding directory
      fetchSqlite3Doc = builtins.fetchurl {
        url = "https://www.sqlite.org/${year}/sqlite-doc-${serialisedVersion}.zip";
        sha256 = "1bcdy1179r46bpvyfy9plhjfy2nr9zdd1mcp6n8n62cj3vvidp0s";
      };
      sqlite3DocDir = "sqlite-doc-${serialisedVersion}";
  in rec {
    packages.${system} = {
        # sqlite3 autoconf
        sqlite3-bin = pkgs.stdenv.mkDerivation {
            pname = "sqlite3-bin";
            inherit version;

            srcs = [ fetchSqlite3Autoconf ];
            sourceRoot = "${sqlite3SrcDir}";

            outputs = [ "out" ];

            nativeBuildInputs = 
                [ 
                    # `readline` makes the CLI interface usable
                    pkgs.readline 
                ];

            configureFlags = 
                [
                    # Some awkwardness to refer to the environment variable `$out`.
                    # See [here](https://nixos.org/manual/nix/stable/release-notes/rl-2.0.html)
                    "--prefix=${builtins.placeholder "out"}" 
                    "--enable-readline"
                    "--enable-threadsafe"
                    "--enable-math"
                    "--enable-fts4"
                    "--enable-fts5"
                ];
        };

        # HTML sqlite3 documentation
        sqlite3-doc = pkgs.stdenv.mkDerivation {
            pname = "sqlite3-doc";
            inherit version;

            srcs = [ fetchSqlite3Doc ];
            sourceRoot = "${sqlite3DocDir}";

            outputs = [ "out" ];

            nativeBuildInputs = 
                [ 
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
            installPhase = ''
                set -e
                runHook preInstall

                mkdir -p $out/share/doc
                cp -r .  $out/share/doc
                
                # Check if `index.html` exists
                file "$out/share/doc/index.html"

                runHook postInstall
            '';
        };

        # Convienent shell function to open documentation similar to `nixos-help`
        sqlite3-help = pkgs.writeShellScriptBin "sqlite3-help" ''
          # Finds first executable browser in a colon-separated list.
          # (see how xdg-open defines BROWSER)
          browser="$(
            IFS=: ; for b in $BROWSER; do
              [ -n "$(type -P "$b" || true)" ] && echo "$b" && break
            done
          )"
          if [ -z "$browser" ]; then
            browser="$(type -P xdg-open || true)"
            if [ -z "$browser" ]; then
              browser="${pkgs.w3m-nographics}/bin/w3m"
            fi
          fi
          exec "$browser" "${packages."${system}".sqlite3-doc + "/share/doc/index.html"}"
        '';

        # Convenient derivation to amalmagate the above derivations into a
        # single derivation.
        default = pkgs.symlinkJoin {
            name = "sqlite3";
            paths = 
                [ 
                    packages.${system}.sqlite3-bin
                    packages.${system}.sqlite3-doc
                    packages.${system}.sqlite3-help
                ];
        };
    };

    # Amalmagates the above derivations. For details on `mkShell`, see
    # [here](https://github.com/NixOS/nixpkgs/blob/master/pkgs/build-support/mkshell/default.nix)
    devShells.${system} = {
        default = pkgs.mkShell {
            name = "sqlite3";
            packages = [ packages.${system}.default ];
        };
    };
  };
}
