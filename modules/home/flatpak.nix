{
  inputs,
  ...
}:

{
  imports = [
    # The module attr is `nix-flatpak`; upstream's flake ships no `default`
    # alias. Input is rev-locked in flake.lock.
    inputs.nix-flatpak.homeManagerModules.nix-flatpak
  ];

  services.flatpak = {
    enable = false;
    uninstallUnmanaged = false;
    uninstallUnused = false;
    update.onActivation = false;
    remotes = [
      {
        name = "flathub";
        location = "https://flathub.org/repo/flathub.flatpakrepo";
      }
    ];
    packages = [
      "org.libreoffice.LibreOffice"
      "it.fabiodistasio.AntaresSQL"
      "net.lutris.Lutris"
      "org.mozilla.firefox"
      "io.github.gtkwave.GTKWave"
      "io.github.ra3xdh.qucs_s"
      "org.inkscape.Inkscape"
      "org.gnucash.GnuCash"
      "com.usebottles.bottles"
      "org.otfried.Ipe"
      "com.jgraph.drawio.desktop"
      "org.mozilla.Thunderbird"
      "org.torproject.torbrowser-launcher"
      "md.obsidian.Obsidian"
      "org.zotero.Zotero"
      "org.jdownloader.JDownloader"
      "org.kde.labplot"
      "fm.reaper.Reaper"
      "ar.com.tuxguitar.TuxGuitar"
      "net.ankiweb.Anki"
      "org.videolan.VLC"
      "net.cozic.joplin_desktop"
      "com.valvesoftware.Steam"
      "org.telegram.desktop"
      "com.discordapp.Discord"
      "com.spotify.Client"
      "im.riot.Riot"
      "org.signal.Signal"
      "org.keepassxc.KeePassXC"
      "org.gnome.meld"
      "com.prusa3d.PrusaSlicer"
      "org.freecad.FreeCAD"
      "org.openscad.OpenSCAD"
      "org.kicad.KiCad"
      "org.gimp.GIMP"
      "org.sqlitebrowser.sqlitebrowser"
      "org.kde.kdenlive"
    ];
  };
}
