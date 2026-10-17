{
  config,
  inputs,
  pkgs,
  ...
}:

let
  nixbitsLib = inputs.nixbits.lib.mkNodeLib pkgs;

  s3Host = "nwv-srv";
  s3Port = "8333";
  socketPath = "%t/sccache/sccache.sock";

  # The backend probe both scripts share: a raw TCP connect with a hard
  # timeout, like the bash /dev/tcp trick it replaces. The S3 endpoint only
  # answers HTTP for real requests, so a plain connection test is the
  # reliable reachability signal.
  probe = ''
    const net = require("node:net");

    const tcpOpen = (host: string, port: number, timeoutMs: number): Promise<boolean> =>
      new Promise((resolve) => {
        const socket = net.connect({ host, port });
        const done = (ok: boolean): void => {
          socket.destroy();
          resolve(ok);
        };
        socket.setTimeout(timeoutMs);
        socket.once("connect", () => done(true));
        socket.once("timeout", () => done(false));
        socket.once("error", () => done(false));
      });
  '';

  # The daemon owns the remote-vs-local storage decision: its env is fixed at
  # start, so the mode must be chosen (and re-chosen) outside the daemon.
  # sccache-pick.service probes nwv-srv and writes a systemd EnvironmentFile
  # plus a mode marker that the recheck timer compares against. It must run
  # as its own unit ordered Before the daemon: EnvironmentFile is read at
  # daemon start, before any ExecStartPre of that unit could write it.
  # Clients never pass storage env themselves (~/bin/sccache-wrapper only
  # points at the socket), which is what lets sandboxed builds ride this
  # daemon.
  pickMode = nixbitsLib.ts (
    probe
    + ''
      main(async () => {
        const runtime = requireEnv("RUNTIME_DIRECTORY");
        if (await tcpOpen("${s3Host}", ${s3Port}, 2000)) {
          writeFileAtomic(runtime + "/env", [
            "SCCACHE_BUCKET=sccache",
            "SCCACHE_ENDPOINT=http://${s3Host}:${s3Port}",
            "SCCACHE_S3_USE_SSL=false",
            "SCCACHE_REGION=us-east-1",
            "AWS_ACCESS_KEY_ID=sccache",
            "AWS_SECRET_ACCESS_KEY=sccache",
            "SCCACHE_IDLE_TIMEOUT=0",
          ].join("\n") + "\n");
          writeFileAtomic(runtime + "/mode", "remote\n");
        } else {
          writeFileAtomic(runtime + "/env", [
            "SCCACHE_DIR=${config.home.homeDirectory}/.cache/sccache",
            "SCCACHE_CACHE_SIZE=5G",
            "SCCACHE_IDLE_TIMEOUT=0",
          ].join("\n") + "\n");
          writeFileAtomic(runtime + "/mode", "local\n");
        }
      });
    ''
  );

  # If backend reachability flipped since the daemon started, restart it so
  # the mode is never stale for long. A restart is cheap: the cache lives on
  # disk (or in S3), only in-memory stats are lost.
  recheck = nixbitsLib.ts (
    probe
    + ''
      main(async () => {
        const { existsSync, readFileSync } = require("node:fs");
        const modeFile = requireEnv("XDG_RUNTIME_DIR") + "/sccache/mode";
        if (!existsSync(modeFile)) return;
        const mode = (await tcpOpen("${s3Host}", ${s3Port}, 2000)) ? "remote" : "local";
        if (mode !== readFileSync(modeFile, "utf8").trim()) {
          run("systemctl", "--user", "restart", "sccache-daemon.service");
        }
      });
    ''
  );
in
{
  systemd.user.services.sccache-pick = {
    Unit.Description = "Probe sccache backend reachability and write its env file";
    Service = {
      Type = "oneshot";
      # Shared with sccache-daemon, which also declares it: the dir stays
      # alive as long as either unit references it.
      RuntimeDirectory = "sccache";
      ExecStart = "${pickMode}";
    };
  };

  systemd.user.services.sccache-daemon = {
    Unit = {
      Description = "sccache daemon (remote S3 when reachable, else local)";
      # On login, start even though the daemon also self-starts on first use:
      # sandboxed clients cannot spawn a remote-configured daemon themselves.
      Wants = [ "sccache-recheck.timer" ];
      Requires = [ "sccache-pick.service" ];
      After = [ "sccache-pick.service" ];
    };
    Service = {
      Type = "forking";
      RuntimeDirectory = "sccache";
      Environment = "SCCACHE_SERVER_UDS=${socketPath}";
      # Read at start, i.e. after sccache-pick has written it (After above).
      EnvironmentFile = "-%t/sccache/env";
      # A crashed daemon leaves the socket file behind and the next bind
      # would fail with EADDRINUSE.
      ExecStartPre = "${pkgs.coreutils}/bin/rm -f ${socketPath}";
      ExecStart = "${pkgs.sccache}/bin/sccache --start-server";
      # This is a single-user nix setup (no nixbld build users, see
      # nix.conf): every client, including sandboxed builds, runs as this
      # user, so owner-only perms on the socket suffice.
      ExecStartPost = "${pkgs.coreutils}/bin/chmod 0755 ${socketPath}";
      Restart = "always";
      RestartSec = "5";
    };
    Install.WantedBy = [ "default.target" ];
  };

  systemd.user.services.sccache-recheck = {
    Unit.Description = "Restart sccache-daemon if backend reachability changed";
    Service = {
      Type = "oneshot";
      ExecStart = "${recheck}";
    };
  };

  systemd.user.timers.sccache-recheck = {
    Unit.Description = "Periodically re-probe sccache backend reachability";
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "5min";
      Unit = "sccache-recheck.service";
    };
    Install.WantedBy = [ "timers.target" ];
  };

  # Make sure the units actually start on switch/login.
  systemd.user.startServices = "sd-switch";
}
