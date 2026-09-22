# elliancarlos.com.br

[![Netlify Status](https://api.netlify.com/api/v1/badges/703975f3-d832-4bd3-8051-d6ca4f375a5a/deploy-status)](https://app.netlify.com/sites/serene-lollipop-e973ed/deploys)

Personal website and blog of Ellian Carlos. The site is live at
[elliancarlos.com.br](https://www.elliancarlos.com.br).

## Stack

| Part                    | Tool                                                             |
| ----------------------- | ---------------------------------------------------------------- |
| Static site generator   | [Eleventy](https://www.11ty.dev/) 2.x                            |
| Templates               | Nunjucks and Markdown                                            |
| Package manager         | [Bun](https://bun.sh/)                                           |
| Styles                  | TTY design system (vendored, `src/styles/tty/`)                   |
| Client-side search      | [FlexSearch](https://github.com/nextapps-de/flexsearch)          |
| Development environment | Nix, [devenv](https://devenv.sh/), [direnv](https://direnv.net/) |
| Hosting                 | Netlify                                                          |
| Build check             | `scripts/check-build.sh` (assertions over `dist/`)                |

## Prerequisites

You need Nix, direnv, and devenv on your system. Install them in this order.

1. Install Nix. On Linux, use the multi-user installation:

   ```bash
   sh <(curl -L https://nixos.org/nix/install) --daemon
   ```

   On Windows Subsystem for Linux (WSL), use the single-user installation:

   ```bash
   sh <(curl -L https://nixos.org/nix/install) --no-daemon
   ```

2. Enable the `nix-command` and `flakes` features:

   ```bash
   mkdir -p ~/.config/nix
   echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
   ```

3. Install direnv. Use the package manager of your distribution:

   ```bash
   sudo apt install direnv     # Ubuntu, Debian, WSL
   sudo pacman -S direnv       # Arch Linux
   ```

   For other distributions, see the
   [direnv installation guide](https://direnv.net/docs/installation.html).

4. Add the direnv hook to your shell. Then reload the shell:

   ```bash
   echo 'eval "$(direnv hook bash)"' >> ~/.bashrc   # bash
   echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc     # zsh
   ```

5. Install devenv:

   ```bash
   nix profile install --accept-flake-config nixpkgs#devenv
   ```

## Setup

```bash
git clone https://github.com/EllianCarlos/elliancarlos.github.io.git
cd elliancarlos.github.io
direnv allow
```

The `direnv allow` command builds the development shell, installs Bun, and
installs the project dependencies. The first run takes a few minutes.

After setup, direnv loads the environment each time you enter the directory.

## Commands

| Command         | Action                                                     |
| --------------- | ---------------------------------------------------------- |
| `bun run start` | Start the development server with live reload on port 8080 |
| `bun run build` | Build the production site into `dist/`                     |
| `bun run clean` | Delete the `dist/` folder                                  |

The devenv shell also exposes `build` and `clean` as bare scripts. The
`processes.dev.exec` process runs `bun run start`.

The project has no unit test suite and no linter. Verification is
`bun run build && ./scripts/check-build.sh` — an assertion harness that runs over the
built `dist/` tree. The script never builds, so it cannot fight `bun run start`; stop the
dev server before you build. Add an assertion to `scripts/check-build.sh` for every
change you make — it is the only regression net this repository has.

Prettier formats the source files. See `.prettierrc` for the configuration.

## Layout

```
.eleventy.js    Eleventy configuration: collections, filters, permalinks, transforms
src/
  _data/        Global data: SEO constants and interface strings
  _includes/    Layouts and partial templates
  en/           English pages and blog posts
  scripts/      Client-side JavaScript, for example the search code
  styles/       CSS
  tag/          Tag page template
public/         Static files copied to the site root
dist/           Build output; git ignores this folder
```

Read `.eleventy.js` first. It holds almost all custom build behaviour.

`CLAUDE.md` documents the architecture in detail. It also explains the
internationalization (i18n) machinery, which the site disables today.

## Deployment

Netlify builds and deploys the `main` branch. The `CNAME` file sets the custom
domain. The `public/_headers` file sets the cache-control rules.

## License

See [LICENSE.md](LICENSE.md).
