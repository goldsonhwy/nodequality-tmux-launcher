# NodeQuality tmux launcher

This repository provides a small Bash wrapper for the NodeQuality benchmark. It:

- Installs `curl` and `tmux` with `apt-get` when either is missing.
- Starts the benchmark inside a detached tmux session, so an SSH disconnect does not stop it.
- Sends the requested answers automatically: `v`, `y`, `y`, `y`.
- Lets you reconnect later and inspect the live output.

## One-line usage

Run this on the target Debian/Ubuntu server as a user with root access or passwordless `sudo`:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/OWNER/REPOSITORY/main/nodequality-tmux.sh)
```

Replace `OWNER/REPOSITORY` with the actual GitHub path after publishing this repository.

The script starts the job and returns immediately. Reconnect to the running output with:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/OWNER/REPOSITORY/main/nodequality-tmux.sh) attach
```

Inside tmux, detach while keeping the benchmark running with `Ctrl-b`, then `d`.

## Commands

```bash
# Start the benchmark in tmux
bash nodequality-tmux.sh

# Attach to the live output
bash nodequality-tmux.sh attach

# Check whether it is still running
bash nodequality-tmux.sh status

# Read the saved output after reconnecting
cat ~/nodequality-nodequality.log

# Stop the tmux session
bash nodequality-tmux.sh stop
```

The default tmux session name is `nodequality`. To use another name:

```bash
NODEQUALITY_TMUX_SESSION=my-test bash nodequality-tmux.sh
NODEQUALITY_TMUX_SESSION=my-test bash nodequality-tmux.sh attach
```

The wrapper intentionally uses the current `run.NodeQuality.com` script at execution time. Review that upstream script before running it on a production server, because it downloads additional test components and requires mount/chroot privileges during the benchmark.
