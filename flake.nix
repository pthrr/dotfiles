{
  description = "Dotfiles: dev shells, home-manager configuration and checks";

  inputs = {
    # Include the nixbits submodule in this flake's source; without it Nix
    # copies an empty directory and `import ./nixbits` fails.
    self.submodules = true;
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Was previously fetched unpinned via fetchTarball <latest.tar.gz> in the
    # home-manager imports; now a lockfile-pinned flake input.
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    # Not in nixpkgs. Follows this flake's nixpkgs, so it builds with this
    # nixpkgs' Zig; `task update` moves it to its newest commit with the other
    # inputs.
    monstar = {
      url = "github:rockorager/monstar";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      ...
    }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      eachSystem =
        f:
        builtins.listToAttrs (
          map (system: {
            name = system;
            value = f nixpkgs.legacyPackages.${system} system;
          }) systems
        );
    in
    {
      devShells = eachSystem (
        pkgs: system: {
          default = pkgs.mkShell {
            packages =
              with pkgs;
              [
                biome
                go-task
                pre-commit
                nixfmt
                nodejs
                shellcheck
                stylua
                watchexec
              ]
              # The home-manager flake does not publish x86_64-darwin packages.
              ++ (nixpkgs.lib.optional (system != "x86_64-darwin") (
                home-manager.packages.${system}.home-manager
              ));
          };
        }
      );

      # `nix fmt` entry point. nixfmt reads stdin when given no files, so
      # default to every .nix file git tracks or would track under the flake
      # root (PRJ_ROOT is set by nix fmt). git lists the nixbits submodule as
      # one entry, never its files: nixbits checks its own formatting.
      formatter = eachSystem (
        pkgs: _:
        pkgs.writeShellScriptBin "format-nix" ''
          flags=()
          files=()
          for arg in "$@"; do
            case "$arg" in
              -*) flags+=("$arg") ;;
              *) files+=("$arg") ;;
            esac
          done
          if [ "''${#files[@]}" -eq 0 ]; then
            cd "''${PRJ_ROOT:-.}"
            mapfile -t files < <(git ls-files --cached --others --exclude-standard '*.nix')
          fi
          exec ${pkgs.nixfmt}/bin/nixfmt "''${flags[@]}" "''${files[@]}"
        ''
      );

      # Managed home configuration. The git identity is pinned in
      # modules/home/default.nix, so evaluation is pure and no `--impure` is
      # required.
      homeConfigurations."pthrr@x86_64-linux" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = { inherit inputs; };
        modules = [
          ./modules/home
          # nixbits' `ts` and `tsWithEnv`: the inline TypeScript the
          # modules run (nixbits/README.md). Built against this
          # configuration's pkgs, so a module function rather than an inherit.
          (
            { pkgs, ... }:
            {
              _module.args.nixbitsLib = import ./nixbits { inherit pkgs; };
            }
          )
        ];
      };
    };
}
