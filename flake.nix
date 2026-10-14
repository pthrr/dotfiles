{
  description = "Dotfiles: dev shells, home-manager configuration and checks";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Was previously fetched unpinned via fetchTarball <latest.tar.gz> in the
    # home-manager imports; now a lockfile-pinned flake input.
    nix-flatpak.url = "github:gmodena/nix-flatpak";
    # Not in nixpkgs; pinned by rev. Bump the rev here to upgrade monstar.
    monstar.url = "github:rockorager/monstar/c41132f5570f6b6347ec15c9de5e9417d79f2f50";
    # Git submodule. Flakes do not fetch submodule contents, so the flake
    # consumes the repo itself; keep the pinned rev in flake.lock in sync
    # with `git rev-parse nixbits` (task: nixbits check in task lint).
    nixbits.url = "github:pthrr/nixbits";
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
                go-task
                pre-commit
                nixfmt
                nodejs
              ]
              # The home-manager flake does not publish x86_64-darwin packages.
              ++ (nixpkgs.lib.optional (system != "x86_64-darwin") (
                home-manager.packages.${system}.home-manager
              ));
          };
        }
      );

      # Managed home configuration. Applying it reads the git identity
      # override files (~/.config/git/name.txt / email.txt) at eval time, so
      # the switch must pass `--impure` (see task home).
      homeConfigurations."pthrr@x86_64-linux" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        extraSpecialArgs = { inherit inputs; };
        modules = [ ./modules/home ];
      };
    };
}
