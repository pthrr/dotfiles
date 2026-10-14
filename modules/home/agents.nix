{
  config,
  lib,
  pkgs,
  ...
}:

let
  # OpenCode resolves a plugin entry as a module specifier and does not expand
  # "~", so the shared bridge has to be named by absolute path.
  opencodeConfig = pkgs.writeText "opencode.json" (
    lib.replaceStrings [ "@AGENTS_DIR@" ] [ "${config.home.homeDirectory}/.agents" ] (
      builtins.readFile ../../dotfiles/agents/.agents/opencode/opencode.json.in
    )
  );
in
{
  home.file = {
    # One maintained tree; recurse so local skills can coexist.
    ".agents" = {
      source = ../../dotfiles/agents/.agents;
      recursive = true;
    };
    # Client discovery paths share the same skills and hooks.
    ".codex/hooks.json".source = ../../dotfiles/agents/.agents/codex/hooks.json;
    ".claude/skills" = {
      source = ../../dotfiles/agents/.agents/skills;
      recursive = true;
    };
    # Claude Code loads any ~/.claude/skills/<name> carrying a plugin manifest
    # as <name>@skills-dir, with no marketplace. Hooks live here instead of in
    # settings.json so that file stays writable and /model can save a default.
    ".claude/skills/agent-hooks" = {
      source = ../../dotfiles/agents/.agents/claude/plugin;
      recursive = true;
    };
    # Same skills-dir plugin mechanism, but exposing language servers to
    # Claude Code's built-in LSP tool.
    ".claude/skills/lsp" = {
      source = ../../dotfiles/agents/.agents/claude/lsp;
      recursive = true;
    };
    ".codex/skills" = {
      source = ../../dotfiles/agents/.agents/skills;
      recursive = true;
    };
    # OpenCode finds ~/.agents/skills on its own; only the plugin needs naming.
    ".config/opencode/opencode.json".source = opencodeConfig;
    ".agents/opencode/opencode.json".source = opencodeConfig;
  };
}
