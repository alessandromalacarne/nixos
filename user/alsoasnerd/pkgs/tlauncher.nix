{ pkgs ? import <nixpkgs> {} }:

pkgs.buildFHSEnv {
    name = "tlauncher-fhs";

    targetPkgs = pkgs: with pkgs; [
        glibc
        gcc
        zlib
        libGL
        glib
        gtk3
        openjdk17
        openjfx17
        bashInteractive
        coreutils
        which
    ];
    multiPkgs = pkgs: with pkgs; [
        zlib
        glib
        gtk3
    ];

    profile = ''
    export LD_PRELOAD=""
    export JAVA_HOME=${pkgs.openjdk17}/lib/openjdk
  '';

    runScript = "bash";  # Inicia um shell interativo
}
