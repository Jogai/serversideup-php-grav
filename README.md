# Grav on FrankenPHP

[![Release](https://img.shields.io/github/v/release/jogai/serversideup-php-grav?style=for-the-badge&label=release)](https://github.com/jogai/serversideup-php-grav/releases/latest)
[![Release build](https://img.shields.io/github/actions/workflow/status/jogai/serversideup-php-grav/release.yml?style=for-the-badge&label=release%20build)](https://github.com/jogai/serversideup-php-grav/actions/workflows/release.yml)
[![Image](https://img.shields.io/badge/ghcr.io-jogai%2Fserversideup--php--grav-blue?style=for-the-badge&logo=docker&logoColor=white)](https://github.com/jogai/serversideup-php-grav/pkgs/container/serversideup-php-grav)
[![PHP 8.5](https://img.shields.io/badge/php-8.5-777BB4?style=for-the-badge&logo=php&logoColor=white)](https://www.php.net/)
[![Grav 2](https://img.shields.io/badge/grav-2.x-221E1F?style=for-the-badge)](https://getgrav.org)
[![Renovate](https://img.shields.io/badge/renovate-enabled-1A1F6C?style=for-the-badge&logo=renovate&logoColor=white)](https://github.com/jogai/serversideup-php-grav/issues?q=is%3Aissue+Dependency+Dashboard)
[![License](https://img.shields.io/github/license/jogai/serversideup-php-grav?style=for-the-badge)](LICENSE)

A container image for [Grav CMS](https://getgrav.org) 2.x, built on
[serversideup/php](https://serversideup.net/open-source/docker-php/) `8.5-frankenphp-alpine`:
Caddy and PHP 8.5 in a single process, running as the unprivileged `www-data` user on port 8080.

On top of the base image it:

- adds `git`, for the [Git Sync](https://github.com/trilbymedia/grav-plugin-git-sync) plugin;
- adds the PHP extensions Grav uses that the base lacks: `gd`, `apcu`, `intl` and `exif`
  (`zip`, `pdo_sqlite` and OPcache are already there), and disables `pdo_mysql`, `pdo_pgsql`,
  `redis` and `pcntl`;
- ports the security rules from Grav's `webserver-configs/nginx.conf` to Caddy
  ([`grav.caddyfile`](grav.caddyfile)). Only `index.php`
  can run PHP; config, accounts, page Markdown, templates and core sources answer 403;
- serves the site from `/var/www/html` (the base expects `/var/www/html/public`);
- enables OPcache (with timestamp checks, since Grav rewrites its compiled config) and a 64 MB
  APCu cache, and limits PHP to 4 threads;
- sets `variables_order = EGPCS`, so `GRAV_CONFIG__*` environment variables reach Grav;
- trusts `X-Forwarded-For` from private networks (a reverse proxy on a Docker network) instead of
  the base image's Cloudflare ranges.

Grav itself is not in the image: mount your site folder at `/var/www/html` and keep updating it
with `bin/gpm`. The image does not run Grav's scheduler.

## Usage

```sh
chown -R 82:82 ./grav        # www-data in the image
docker run -d -p 8080:8080 -v "$PWD/grav:/var/www/html" ghcr.io/jogai/serversideup-php-grav:8.5
```

See [`compose.example.yaml`](compose.example.yaml) for a site behind Traefik with Grav's
config overrides.

Tags:

| Tag | Example | Moves |
|---|---|---|
| `latest`, `8.5` | | with every release |
| `<php>` | `8.5.12` | until the next PHP patch release |
| `<php>-ssu<serversideup>[-r<n>]` | `8.5.12-ssu5.0.2`, `8.5.12-ssu5.0.2-r1` | never (`-r<n>` is a rebuild of the same versions) |

### Settings

Everything serversideup documents in its
[environment variable reference](https://serversideup.net/open-source/docker-php/docs/reference/environment-variable-specification)
still applies. This image changes these defaults:

| Variable | Value |
|---|---|
| `CADDY_SERVER_ROOT` | `/var/www/html` |
| `CADDY_PHP_SERVER_OPTIONS` | `try_files {path} index.php` (keep this when you add options) |
| `FRANKENPHP_CONFIG` | `num_threads 4` |
| `TRUSTED_PROXY` | `local` |
| `SHOW_WELCOME_MESSAGE` | `false` |
| `PHP_MEMORY_LIMIT` | `256M` |
| `PHP_MAX_EXECUTION_TIME` | `120` |
| `PHP_POST_MAX_SIZE`, `PHP_UPLOAD_MAX_FILE_SIZE` | `64M` |
| `PHP_OPCACHE_ENABLE`, `PHP_OPCACHE_VALIDATE_TIMESTAMPS` | `1` |
| `PHP_OPCACHE_MEMORY_CONSUMPTION` | `128` |
| `PHP_OPCACHE_INTERNED_STRINGS_BUFFER` | `16` |
| `PHP_OPCACHE_MAX_ACCELERATED_FILES` | `10000` |
| `PHP_APC_SHM_SIZE` (new) | `64M` |

Grav's nightly jobs (cache purge, backups) can run from the host's crontab:

```
0 4 * * * docker exec grav php bin/grav scheduler
```

## How updates flow

1. Renovate watches `serversideup/php:8.5-frankenphp-alpine-v<version>` in the
   [`Dockerfile`](Dockerfile). It opens a PR for a new serversideup release (new tag) and for a
   rebuild of the current one (new digest, e.g. a PHP patch release or Alpine fixes).
2. The [CI](.github/workflows/ci.yml) workflow builds the image. There are no tests beyond that:
   if it builds, it ships.
3. When the `build` check passes, GitHub's auto-merge merges the PR.
4. The merge changes the `Dockerfile` on `main`, which starts the
   [Release](.github/workflows/release.yml) workflow. It builds the image, pushes it to
   `ghcr.io` with an SBOM and a signed provenance attestation, and creates a GitHub release.

Renovate has no schedule and opens one PR at a time. It also keeps the GitHub Actions up to date
(pinned to commit digests). Those PRs are built and automerged too, but don't make a release.
A new serversideup **major** version is not automerged: check its release notes, then merge it
by hand. PHP 8.6 is a different tag line; switch to it by editing the `FROM` line and the
version pattern in [`renovate.json`](renovate.json).

## GitHub setup

1. Install the [Renovate GitHub app](https://github.com/apps/renovate) for this repository.
2. **Settings → General → Pull Requests**: enable *Allow auto-merge* and
   *Automatically delete head branches*.
3. **Settings → Rules → Rulesets**, a ruleset for the default branch (`main`):
   *Require a pull request before merging* with 0 required approvals,
   *Require status checks to pass* with the check `build`, and *Block force pushes*.
   Without a required check, auto-merge merges before the build has finished.
4. After the first release, open the package (**Your profile → Packages**) and, if the image
   should be pullable without logging in, set its visibility to public under *Package settings*.
5. Because `renovate.json` is already in the repository, Renovate skips its onboarding PR. Its
   first PR pins the GitHub Actions to digests; from there on it follows serversideup.
   The *Dependency Dashboard* issue shows what it's waiting on, and ticking a box there starts a
   run straight away.

## License

[GPL-3.0](LICENSE), the same license as serversideup/php.
