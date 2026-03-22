

<span id="top"></span>

# 👨🏻‍💻 Developers

Thank you for considering embarking on this side quest. Let these tomes guide you on your journey. 🕯️

## ⚡ TL;DR — one command

```shell
git clone --recursive https://github.com/{your-fork}/mist-ce.git
cd mist-ce
make dev
```

That's it. `make dev` handles `.env`, submodules, `settings/`, `keys/`, image builds, `docker compose up`, frontend `npm install`, and creates `admin@example.com` / `admin`. Works on Linux x86_64 and macOS Apple Silicon. Run `make help` to see all targets (shells, logs, restart, etc).

Overrides: `make dev ADMIN_EMAIL=me@foo.com ADMIN_PASSWORD=secret PORTAL_URI=http://<vm-ip>`

The rest of this doc explains what `make dev` does under the hood, in case you need to intervene manually.

---

<span id="links"></span>

[*️⃣ 0. Requirements](#requirements) \
[🔀 1. Fork](#fork) \
[⬇️ 2. Clone](#clone) \
[➡️ 3. Settings](#settings) \
[▶️ 4. Start](#start) \
[↕️ 5. NPM](#npm) \
[⏩ 6. Build](#build) \
[🚹 7. User](#user) \
[↩️ 8. Logs](#logs) \
[↗️ 9. Open](#open) \
[🔄 10. Restart](#restart)


> [!TIP]
> Although this works in Docker Desktop, it may be easier to set up a dedicated VM and remotely connect with VSCode or equivalent. That way the environment it always set up ready to go without conflicts. Or use a local Ubuntu development PC with Docker if you're a baller.

> [!NOTE]
> **macOS / Apple Silicon (arm64) is supported.** Several services run under Rosetta emulation (they're pinned to `platform: linux/x86_64` in compose) which adds CPU overhead, but the stack boots and runs. See [Troubleshooting](#troubleshooting) below if containers crash on arm64.

> Target the vx.x.x-staging branch for pull requests, see [BRANCHES.md](./BRANCHES.md)

<br>
<span id="requirements"></span>

## *️⃣ 0. Requirements

* 💫 A universe to exist in (or simulation)
* 🌐 The internet
* 🐋 [Docker](https://docs.docker.com/engine/install/)
* 🐳 [Docker Compose](https://docs.docker.com/compose/install/)
* 🏷️ [git](https://git-scm.com/downloads/linux)
* 🧠 Memory: ~8GB for development
* 🥔 CPU: ~2 Cores
* 💾 Disk: ~50GB when building images

<br>
<span id="fork"></span>

## 🔀 1. Fork

In the [https://github.com/mistcommunity/mist-ce](https://github.com/mistcommunity/mist-ce) repository on GitHub, click the Fork button to create a repository in your own personal GitHub account. 

<br>
<span id="clone"></span>

## ⬇️ 2. Clone
Clone your fork to your development environment (replace with your username):

```shell
git clone --recursive https://github.com/{yourgithubusername}/mist-ce.git
cd mist-ce
```

> [!IMPORTANT]
> The `--recursive` flag is **required** — it pulls in the `api/lc` (Apache Libcloud) submodule which the API image build depends on. If you cloned without it, run:
> ```shell
> git submodule update --init --recursive
> ```

By cloning the directory, there is also a `docker-compose.override.yml` file in the current directory in addition to `docker-compose.yml`. This is used to modify the configuration for development mode, which mounts the files in to the containers, overriding the files in the images.

<br>
<span id="settings"></span>

## ➡️ 3. Settings

> [!NOTE]
> This will be simpler in the future

1. Copy `.env.template` to `.env` — the defaults (`IMG_REGISTRY=ghcr.io/mistcommunity`, `IMG_TAG=v4.8.2`, `CONF_DIR=/etc/mist`) should work out of the box. Adjust `IMG_TAG` if working on a different version.
2. Create the local `settings/` and `keys/` directories that compose bind-mounts into the containers:
   ```shell
   mkdir -p settings keys
   cp api/settings/settings.py settings/settings.py
   ```
3. In `settings/settings.py`, set `JS_BUILD = False` — this tells the server to serve source JavaScript files from the dev server instead of minified bundles, so UI edits show up live.
4. In `settings/settings.py`, set `PORTAL_URI` to match how you'll access the app (e.g. `"http://localhost"` for local Docker Desktop, or the host IP for a remote VM).

This will mount the checked out code into the containers and may take some time.

<br>
<span id="start"></span>

## ▶️ 4. Start

> [!TIP]
> If you are not interested in front-end development, you can comment out the UI sections within the `docker-compose.override.yml` file.

> [!NOTE]
> The published images at `ghcr.io/mistcommunity/*` may no longer be available. If `docker compose up` fails to pull them, build locally first — the override file provides build contexts for every service:
> ```shell
> docker compose build
> ```
> First build takes ~10-20 min depending on hardware.

Now run
```
docker compose up -d
```

Expect four containers to show `exited (0)` in `docker compose ps` — these are one-shot init jobs and exiting is normal: `vault-init`, `init-secrets`, `apply-migrations`, `elasticsearch-manage`.

<br>
<span id="npm"></span>

## ↕️ 5. NPM
Because the dev override bind-mounts `./ui` and `./portal` over the image directories, the `node_modules` baked into the images are shadowed. You **must** install dependencies into the host-mounted directories or the page will render blank:

```shell
docker compose exec ui npm install
docker compose exec portal npm install
docker compose restart ui portal
```

If you want to build the UI bundles:

```shell
docker compose exec ui npm run build
```

As mentioned, when doing front-end development, it is usually more convenient to serve the source code instead of the bundles. To do that, edit `settings/settings.py` and set `JS_BUILD = False`. Restart the `api` container for the changes to take effect with:

```
./restart.sh api
```

<br>
<span id="build"></span>

## ⏩ 6. Build

**Optional**, if you want to build the images locally, and push to your own image repository (Docker Hub or GitHub), then modify the `.env` file.

`IMG_REGISTRY=ghcr.io/<GitHub user or organization name>` \
or \
`IMG_REGISTRY=<your dockerhub user name>` 

Change the version tag if you wish \
`IMG_TAG=4.20.69`

Then build the images:

```shell
docker compose build
docker compose up -d --wait
```

> [!NOTE]
> This will build all the Docker images and start them and it can take some time depending on performance of your computer. It is also expected that it will use quite a lot of disk space and RAM.

If you want to push to your repository, do:

```
docker compose push
```

<br>
<span id="user"></span>

## 🚹 7. User
```shell
docker compose exec api sh -c './bin/adduser --admin admin@example.com'
```

<br>
<span id="logs"></span>

## ↩️ 8. Logs
To check on the progress and look for errors, tail the docker compose logs

```shell
docker compose logs -f
```

<br>
<span id="open"></span>

## ↗️ 9. Open 
If all looks good...
1. Open your browser and go to the Docker environment IP address (http port 80 only)
2. Login with the credentials you just created
3. ...
4. profit?

<br>
<span id="restart"></span>

## 🔄 10. Restart

You will need to make the restart script executable:
```
sudo chmod +x restart.sh
```

When modifying the API, restart by running (from the root of the project):
```
./restart.sh api
```

When modifying the UI, sometimes you may need to restart it and clear your browser cache: 
```
./restart.sh ui
```

Or just restart everything
```
./restart.sh
```

<br>
<span id="troubleshooting"></span>

## 🩹 Troubleshooting

### Blank page / login form never appears
The dev bind-mounts shadow the image's `node_modules`. Run `docker compose exec ui npm install && docker compose exec portal npm install` then `docker compose restart ui portal`.

### `IMG_REGISTRY` / `IMG_TAG` / `CONF_DIR` variable is not set
You forgot to copy `.env.template` → `.env`.

### `COPY lc /mist.api/lc` fails during API build
The `api/lc` submodule wasn't cloned. Run `git submodule update --init --recursive`.

### logstash: `runtime: failed to create new OS thread ... errno=22`
Apple Silicon / arm64 only. The old Go `env2yaml` helper inside `logstash:7.10.1` is incompatible with Rosetta emulation. The repo has been updated to use `logstash:7.17.28` which ships native arm64 images. If you see this on an older checkout, edit `docker/logstash/Dockerfile` to use `FROM logstash:7.17.28` and remove the `platform: linux/x86_64` line from the `logstash` service in `docker-compose.yml`, then `docker compose build logstash && docker compose up -d logstash`.

### nginx: `io_setup() failed (38: Function not implemented)`
Harmless warning on arm64 under emulation — nginx falls back from AIO to standard I/O. The service still works.

### `docker compose up` fails pulling `ghcr.io/mistcommunity/*`
The published images may be gone. Build locally: `docker compose build` (the override file provides build contexts).

<br>

[Back to top](#top)