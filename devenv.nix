{ pkgs, lib, config, inputs, ... }:

{
  # https://devenv.sh/basics/
  env.GREET = "devenv";

  # https://devenv.sh/packages/
  packages = [ 
    pkgs.git 
  ];

  # https://devenv.sh/languages/
  languages.javascript = {
    enable = true;
    bun.enable = true;
    bun.install.enable = true;
  };

  # https://devenv.sh/processes/
  processes.dev.exec = "bun run start";

  # https://devenv.sh/scripts/
  scripts.build.exec = "bun run build";
  scripts.clean.exec = "bun run clean";

  enterShell = ''
    echo "🚀 Welcome to the Eleventy development environment!"
    echo "📦 Using Bun as the package manager"
    echo ""
    echo "Available commands:"
    echo "  bun run start  - Start development server"
    echo "  bun run build  - Build the site"
    echo "  bun run clean  - Clean dist folder"
    echo ""
  '';

  # https://devenv.sh/pre-commit-hooks/
  # pre-commit.hooks.shellcheck.enable = true;
}
