{
  commonUser,
  pkgs,
  ...
}:

{
  programs.jujutsu = {
    enable = true;
    settings = {
      user = commonUser;
      core = {
        editor = "nvim";
        pager = "less -+$LESS -FRX";
      };

      git = {
        auto-local-bookmark = true;
        push-branch-prefix = "";
        fetch-tags = true;
        track-branches = true;
      };

      operation = {
        allow-empty = true;

        rebase = {
          auto-squash = true;
          update-refs = true;
        };
      };

      # Revset aliases for powerful commit filtering
      revset-aliases = {
        "mine()" = ''author(email_substring("pthrr")) | committer(email_substring("pthrr"))'';
        "trunk()" = "main@origin | master@origin";
        "stack()" = "ancestors(@, mutable())";
      };

      aliases = {
        # Git-equivalent aliases
        co = [ "checkout" ];
        br = [
          "branch"
          "list"
        ];
        cm = [ "new" ];
        df = [ "diff" ];
        lg = [
          "log"
          "--graph"
        ];
        rb = [ "rebase" ];
        mt = [ "resolve" ];

        # Workflow shortcuts
        st = [ "status" ];
        l = [
          "log"
          "-r"
          "trunk()..@"
          "--limit"
          "20"
        ];
        ll = [
          "log"
          "--limit"
          "50"
        ];
        s = [ "show" ];
        n = [ "new" ];
        e = [ "edit" ];

        # Advanced workflows
        amend = [ "squash" ];
        fixup = [ "squash" ];
        uncommit = [
          "edit"
          "@-"
        ];

        # Git integration
        fetch = [
          "git"
          "fetch"
        ];
        pull = [
          "git"
          "fetch"
        ];
        push = [
          "git"
          "push"
        ];

        # Git command aliases
        git-fetch = [
          "git"
          "fetch"
          "--prune"
        ];
        git-push = [
          "git"
          "push"
          "--follow-tags"
        ];
        git-status = [
          "git"
          "status"
        ];
        git-log = [
          "git"
          "log"
          "--oneline"
          "--graph"
          "--decorate"
        ];
        git-diff = [
          "git"
          "diff"
        ];
        git-commit = [
          "git"
          "commit"
          "-v"
        ];
        git-branch = [
          "git"
          "branch"
        ];
        git-rebase = [
          "git"
          "rebase"
        ];
        git-merge = [
          "git"
          "merge"
        ];
      };

      diff = {
        tool = "difftastic";
      };

      merge = {
        tool = "meld";
      };

      fetch = {
        all = true;
      };

      push = {
        auto-setup-remote = true;
      };

      pager = {
        enabled = true;
      };

      ui = {
        default-command = "status";
        color = "auto";
        diff-context = 8;
        diff-editor = ":builtin";
        merge-editor = "meld";
        paginate = "auto";
        log-synthetic-elided-nodes = true;
      };

      # Template customizations
      template-aliases = {
        "format_short_change_id(id)" = "id.shortest(8)";
        "format_short_commit_id(id)" = "id.shortest(8)";
      };
    };
  };

  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    lfs.enable = true;
    signing.format = "openpgp";
    settings = {
      user = {
        name = commonUser.name;
        email = commonUser.email;
      };
      core = {
        editor = "nvim";
        pager = "less -+$LESS -FRX";
        autocrlf = false;
        excludesfile = "~/.config/git/.gitignore_global";
        attributesfile = "~/.config/git/.gitattributes_global";
      };

      branch = {
        sort = "-committerdate";
      };

      tag = {
        sort = "version:refname";
      };

      init = {
        defaultBranch = "main";
      };

      merge = {
        conflictstyle = "zdiff3";
        tool = "meld";
      };

      diff = {
        algorithm = "histogram";
        colorMoved = "plain";
        mnemonicPrefix = true;
        renames = true;
        tool = "meld";
      };

      credential = {
        helper = "cache --timeout=3600";
      };

      gpg = {
        program = "gpg2";
      };

      submodule = {
        recurse = true;
      };

      fetch = {
        prune = true;
        pruneTags = true;
        all = true;
      };

      pull = {
        ff = "only";
        rebase = true;
      };

      push = {
        recurseSubmodules = "on-demand";
        default = "simple";
        autoSetupRemote = true;
        followTags = true;
      };

      commit = {
        verbose = true;
        template = "~/.config/git/git-commit-template.txt";
      };

      rerere = {
        enabled = true;
        autoupdate = true;
      };

      rebase = {
        autoSquash = true;
        autoStash = true;
        updateRefs = true;
      };

      status = {
        submoduleSummary = true;
      };

      difftool = {
        prompt = true;

        "difftastic" = {
          cmd = "difft \"$LOCAL\" \"$REMOTE\"";
          trustExitCode = true;
        };

        "meld" = {
          cmd = "meld \"$LOCAL\" \"$REMOTE\"";
          trustExitCode = false;
        };

        "kdiff3" = {
          cmd = "kdiff3 \"$LOCAL\" \"$REMOTE\"";
          trustExitCode = false;
        };

        "bcomp4" = {
          cmd = "\"/mnt/c/Program Files/Beyond Compare 4/BComp.exe\" \"$(wslpath -w $LOCAL)\" \"$(wslpath -w $REMOTE)\"";
          trustExitCode = true;
        };
      };

      mergetool = {
        keepBackup = false;

        "meld" = {
          cmd = "meld --auto-merge \"$LOCAL\" \"$BASE\" \"$REMOTE\" --output \"$MERGED\" --label=Local --label=Base --label=Remote --diff \"$BASE\" \"$LOCAL\" --diff \"$BASE\" \"$REMOTE\"";
          trustExitCode = false;
        };

        "kdiff3" = {
          cmd = "kdiff3 \"$LOCAL\" \"$BASE\" \"$REMOTE\" \"$MERGED\"";
          trustExitCode = false;
        };

        "bcomp4" = {
          cmd = "\"/mnt/c/Program Files/Beyond Compare 4/BComp.exe\" \"$(wslpath -w $LOCAL)\" \"$(wslpath -w $REMOTE)\" \"$(wslpath -w $BASE)\" \"$(wslpath -w $MERGED)\"";
          trustExitCode = true;
        };
      };

      pager = {
        difftool = false;
      };

      alias = {
        a = "add";
        aa = "add --all";
        b = "branch";
        p = "push";
        pf = "push --force-with-lease";
        c = "commit";
        ca = "commit --amend";
        co = "checkout";
        sw = "!git checkout $(git branch --sort=-committerdate | fzf | sed 's/^[* ] //')";
        s = "status";
        d = "diff";
        dt = "difftool";
        m = "merge";
        mt = "mergetool";
        l = "log";
        lg = "log --graph";
        lo = "log --oneline";
        lp = "log --patch";
        lfp = "log --first-parent";
        lt = "log --topo-order";
        ll = "log --graph --topo-order --date=short --abbrev-commit --decorate --boundary --pretty=format:'%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn]%Creset %Cblue%G?%Creset'";
        lla = "log --graph --topo-order --date=short --abbrev-commit --decorate --all --boundary --pretty=format:'%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn]%Creset %Cblue%G?%Creset'";
        lll = "log --graph --topo-order --date=iso8601-strict --no-abbrev-commit --abbrev=40 --decorate --all --boundary --pretty=format:'%Cgreen%ad %Cred%h%Creset -%C(yellow)%d%Creset %s %Cblue[%cn <%ce>]%Creset %Cblue%G?%Creset'";
        subm-reinit = "!git submodule deinit --all --force && git submodule update --init --recursive";
      };
    };
  };
}
