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

  skills = ../../dotfiles/agents/.agents/skills;

  # Codex skips a SKILL.md that is a symlink but follows a symlinked skill
  # directory, so each skill is linked whole instead of file by file.
  codexSkills = lib.mapAttrs' (
    name: _: lib.nameValuePair ".codex/skills/${name}" { source = skills + "/${name}"; }
  ) (lib.filterAttrs (_: type: type == "directory") (builtins.readDir skills));
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
    # OpenCode finds ~/.agents/skills on its own; only the plugin needs naming.
    ".config/opencode/opencode.json".source = opencodeConfig;
    ".agents/opencode/opencode.json".source = opencodeConfig;
    # One global instructions file under each client's own name; no client
    # reads ~/.agents/AGENTS.md, so the source sits outside that tree.
    ".claude/CLAUDE.md".source = ../../dotfiles/agents/AGENTS.md;
    ".codex/AGENTS.md".source = ../../dotfiles/agents/AGENTS.md;
    ".config/opencode/AGENTS.md".source = ../../dotfiles/agents/AGENTS.md;
  }
  // codexSkills;
}
