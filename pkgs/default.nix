{ pkgs ? import ./nixpkgs
, system ? builtins.currentSystem
, fetchFromGitHub ? (pkgs {}).fetchFromGitHub
, fetchurl ? (pkgs {}).fetchurl
, rustOverlay ? fetchFromGitHub {
    owner  = "mozilla";
    repo   = "nixpkgs-mozilla";
    rev    = "7e54fb37cd177e6d83e4e2b7d3e3b03bd6de0e0f";
    sha256 = "1shz56l19kgk05p2xvhb7jg1whhfjix6njx1q4rvrc5p1lvyvizd";
  }
, racket2nix ? import ./racket2nix { inherit system; }
}:

pkgs {
  inherit system;
  overlays = [
    (import (builtins.toPath "${rustOverlay}/rust-overlay.nix"))
    (self: super: rec {
      rust = let
        fromManifestFixed = manifest: sha256: { stdenv, fetchurl, patchelf }:
          self.lib.rustLib.fromManifestFile
            (fetchurl { url = manifest; sha256 = sha256; })
            { inherit stdenv fetchurl patchelf; };
        rustChannelOfFixed = manifest_args: sha256: fromManifestFixed
          (self.lib.rustLib.manifest_v2_url manifest_args) sha256
          { inherit (self) stdenv fetchurl patchelf; };
        channel = rustChannelOfFixed
          { date = "2018-05-30"; channel = "nightly"; }
          "06w12izi2hfz82x3wy0br347hsjk43w9z9s5y6h4illwxgy8v0x8";
      in {
        rustc = channel.rust;
        inherit (channel) cargo;
      };
      inherit racket2nix;
      inherit (racket2nix) buildRacket;
      rustPlatform = super.recurseIntoAttrs (super.makeRustPlatform rust);
      fractalide = self.buildRacket {
        package = builtins.filterSource (path: type:
          (type != "symlink" || null == builtins.match "result.*" (baseNameOf path)) &&
          (null == builtins.match ".*[.]nix" path) &&
          (null == builtins.match "[.].*[.]swp" path) &&
          (null == builtins.match "[.][#].*" path) &&
          (null == builtins.match "[#].*[#]" path) &&
          (null == builtins.match ".*~" path)
        ) ./..;
      };

      # This simple switcheroo only works because fractalide happens to depend on all of
      # compiler-lib's dependencies.
      fractalide-tests-pkg = fractalide.racketDerivation.override { src = fetchurl {
        url = "https://download.racket-lang.org/releases/6.12/pkgs/compiler-lib.zip";
        sha1 = "8921c26c498e920aca398df7afb0ab486636430f";
      }; };

      fractalide-tests = self.runCommand "fractalide-tests" {
        buildInputs = [ fractalide-tests-pkg.env ];
      } ''
        racket -l- raco test ${fractalide.env}/share/racket/pkgs/*/modules/rkt/rkt-fbp/agents
      '';
    })
  ];
}
