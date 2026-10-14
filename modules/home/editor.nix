{
  pkgs,
  ...
}:

{
  # All providers are disabled: init.lua silences python/ruby/node/perl via
  # `loaded_*_provider = 0` so checkhealth stays quiet.
  programs.neovim = {
    enable = true;
    sideloadInitLua = true;
    withPython3 = false;
    withRuby = false;
    withPerl = false;
    withNodeJs = false;
    plugins = with pkgs.vimPlugins; [
      nvim-treesitter.withAllGrammars
      plenary-nvim
      telescope-nvim
    ];
  };
}
