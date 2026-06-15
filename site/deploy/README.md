# Deploying the docs site

The documentation site is **built on the server** from a git checkout and served
directly by Nginx out of Hugo's `site/public/` directory. There is no rsync of
build artifacts — deploying means "pull the latest commit and rebuild".

```diagram
╭─ your machine ─╮  git push   ╭─ GitHub ─╮
│ commit + push  │ ──────────▶ │  main    │
╰───────┬────────╯             ╰────┬─────╯
        │ tools/deploy-docs.sh      │ git pull --ff-only
        │ (ssh → /opt/olyg3/        ▼
        │  deploy.sh)        ╭─ server /opt/olyg3/olympia-g3 ─╮
        ╰──────────────────▶ │ git pull → hugo --source site │
                             │ → site/public/ (served by     │
                             │   Nginx under /docs/)         │
                             ╰───────────────────────────────╯
```

## Routine deploy

1. Commit and **push** your docs changes to `main`.
2. From your machine, run:

   ```bash
   tools/deploy-docs.sh
   ```

   This SSHes to `olympia-g3.pbbgaming.com` and runs `/opt/olyg3/deploy.sh`,
   which does `git pull --ff-only` then `hugo --source site --gc --minify`.

The rebuild happens in place on the live `site/public/`, so it is effectively
atomic from a reader's perspective (a request mid-build may rarely hit a
half-written asset — accepted as low risk).

## One-time server setup

On the droplet (Ubuntu 24.04), as a user with sudo:

1. **Install the toolchain.** Hugo *extended* (v0.146.0+) and Go (for the Hextra
   Hugo Module) and git:

   ```bash
   sudo snap install hugo --classic        # or install the extended build another way
   sudo snap install go --classic
   sudo apt-get install -y git
   ```

   Confirm `hugo version` reports `extended`.

2. **Check out the repo** at the path the scripts expect:

   ```bash
   sudo mkdir -p /opt/olyg3
   sudo chown "$USER" /opt/olyg3
   git clone https://github.com/playbymail/olympia-g3 /opt/olyg3/olympia-g3
   ```

3. **Install the server-side deploy script** where `deploy-docs.sh` invokes it:

   ```bash
   cp /opt/olyg3/olympia-g3/tools/deploy.sh /opt/olyg3/deploy.sh
   chmod +x /opt/olyg3/deploy.sh
   ```

   > `deploy.sh` exports a broadened `PATH` so a non-interactive SSH shell can
   > still find `git`, `hugo`, and `go` (snap installs land in `/snap/bin`).

4. **Do the first build** so `site/public/` exists before Nginx points at it:

   ```bash
   /opt/olyg3/deploy.sh
   ```

5. **Configure Nginx.** Install [`nginx.conf`](nginx.conf) as
   `/etc/nginx/sites-available/olympia-g3.pbbgaming.com`, enable it, and reload:

   ```bash
   sudo ln -s /etc/nginx/sites-available/olympia-g3.pbbgaming.com \
              /etc/nginx/sites-enabled/
   sudo nginx -t && sudo systemctl reload nginx
   ```

   The config serves `/docs/` directly from
   `/opt/olyg3/olympia-g3/site/public/` via `alias`. Add TLS separately
   (e.g. `sudo certbot --nginx -d olympia-g3.pbbgaming.com`).

6. **Allow the SSH used by `deploy-docs.sh`.** Ensure your workstation key can
   `ssh olympia-g3.pbbgaming.com` and run `/opt/olyg3/deploy.sh`
   non-interactively.

After this, routine deploys are just `tools/deploy-docs.sh`.
