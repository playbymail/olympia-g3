# Olympia G3 documentation site

Game-master and player documentation for the Olympia G3 play-by-mail engine,
built with [Hugo](https://gohugo.io/) (extended) and the
[Hextra](https://imfing.github.io/hextra/) theme. Content is organized with the
[Diátaxis](https://diataxis.fr/) framework (tutorials, how-to guides, reference,
explanation).

- **Production URL:** <https://olympia-g3.pbbgaming.com/docs>
- **Content lives in:** [`content/`](content/), one directory per Diátaxis mode.

## Requirements

- **Hugo extended**, v0.146.0 or newer (the Hextra theme requires the extended
  build). Check with `hugo version` — the output must include `extended`.
- **Go** 1.20+ — Hextra is wired in as a [Hugo Module](https://gohugo.io/hugo-modules/),
  so Hugo uses the Go toolchain to fetch and cache it. No theme is vendored under
  `themes/`.

The first build downloads the theme module; after that it is cached locally and
builds work offline.

## Local development

From this directory (`site/`):

```bash
hugo server
```

This starts a live-reloading server (default <http://localhost:1313/docs/>).
Edits under `content/`, `hugo.yaml`, etc. refresh in the browser automatically.

To update the theme module to its latest release:

```bash
hugo mod get -u github.com/imfing/hextra
hugo mod tidy
```

## Production build

```bash
hugo
```

Hugo writes the static site to `site/public/`. The build must be clean (no
errors) and all internal links resolve under the `/docs/` base path because
`baseURL` in [`hugo.yaml`](hugo.yaml) is set to
`https://olympia-g3.pbbgaming.com/docs/`.

> Internal links use Hugo's path-aware `relref`/`relURL` (no hardcoded
> leading-slash links), so assets and pages resolve correctly under `/docs/`.

## Deploy

The site is served from a DigitalOcean droplet (Ubuntu 24.04) behind Nginx,
under the `/docs` path of `olympia-g3.pbbgaming.com`. It is **built on the
server** from a git checkout — Nginx serves Hugo's `site/public/` directly, so
deploying means "pull the latest commit and rebuild" (no rsync of artifacts).

Routine deploy, from your machine after **pushing** your changes:

```bash
tools/deploy-docs.sh
```

That SSHes to the droplet and runs `/opt/olyg3/deploy.sh`
([`tools/deploy.sh`](../tools/deploy.sh)), which does `git pull --ff-only` then
`hugo --source site --gc --minify`.

Full instructions, including one-time server setup, are in
[`deploy/README.md`](deploy/README.md).

## Nginx

The reference server block is committed at [`deploy/nginx.conf`](deploy/nginx.conf).
It redirects bare `/docs` to `/docs/`, serves `/docs/` directly from the
checkout's `site/public/` via `alias` + `try_files`, and long-caches Hugo's
fingerprinted assets while keeping HTML revalidated. TLS (certbot / `listen 443`)
is added separately.

## Layout

```
site/
├── hugo.yaml          # site config (baseURL, menu, Hextra params, search)
├── go.mod / go.sum    # Hugo Module deps (the Hextra theme)
├── content/           # documentation, one dir per Diátaxis mode
│   ├── _index.md      # landing page
│   ├── tutorials/     # learning-oriented
│   ├── how-to/        # goal-oriented
│   ├── reference/     # information-oriented
│   └── explanation/   # understanding-oriented
├── deploy/
│   └── nginx.conf     # reference Nginx server block
└── public/            # build output (generated; not committed)
```
