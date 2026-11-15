{ config, pkgs, ... }:

let
  # gh is wrapped so it gets a fresh GH_TOKEN; git does not read that
  # variable, so it needs the same token through a credential helper.
  # The helper is installed in ~/.local/bin because that directory is
  # rw-mapped into ai-jail and the absolute path stays valid there.
  clunkerToken = "${config.home.homeDirectory}/.local/bin/clunker-token.sh";
  credentialHelper = pkgs.writeShellScript "git-credential-clunker" ''
    set -eu
    [ "''${1:-}" = "get" ] || exit 0
    token="$(${clunkerToken} 2>/dev/null || true)"
    case "$token" in
      ""|"null") exit 1 ;;
    esac
    printf 'username=x-access-token\npassword=%s\n' "$token"
  '';
in
{
  # chezmoi: dot_gitconfig, merged with the entries the live ~/.gitconfig had
  # grown since (safe.directory = *, gpg."ssh".allowedSignersFile); the stale
  # safe.directory = /opt/flutter from the chezmoi copy is dropped.
  programs.git = {
    enable = true;

    signing = {
      key = "/home/alsoasnerd/.ssh/id_ed25519.pub";
      format = "ssh";
      signByDefault = true;
    };

    # [filter "lfs"] and the git-lfs package come from this option.
    lfs.enable = true;

    settings = {
      credential = {
        "https://github.com".helper = "${config.home.homeDirectory}/.local/bin/git-credential-clunker";
      };

      user = {
        name = "alsoasnerd";
        email = "alsoasnerd@gmail.com";
      };

      safe = {
        directory = "*";
      };

      # Rendered as [gpg "ssh"].
      "gpg.ssh" = {
        allowedSignersFile = "/home/alsoasnerd/.ssh/allowed_signers";
      };

      alias = {
        a = "add";
        ai = "add -i";
        ap = "add -p";
        br = "branch";
        c = "commit -m";
        cl = "clone";
        clean = "!git reset --hard && git clean -df";
        co = "checkout";
        cob = "checkout -b";
        d = "diff";
        done = "!git push --follow-tags origin HEAD";
        fix = "commit --amend -m";
        ft = "fetch";
        i = "init --initial-branch=main";
        l = "log";
        la = "!\"git config -l | grep alias | cut -c 7-\"";
        pl = "pull";
        ps = "push";
        psf = "push --force-with-lease";
        rm = "branch -D";
        s = "status";
        undo = "reset HEAD~1 --mixed";
      };
    };
  };

  home.file.".local/bin/git-credential-clunker".source = credentialHelper;
}
