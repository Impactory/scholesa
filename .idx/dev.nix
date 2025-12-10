# To learn more about how to use Nix to configure your environment
# see: https://developers.google.com/idx/guides/customize-idx-env
{ pkgs, ... }: {
  # Which nixpkgs channel to use.
  channel = "stable-24.05"; # or "unstable"

  # Use https://search.nixos.org/packages to find packages
  packages = [
    pkgs.nodejs_20
    pkgs.firebase-tools # For Firebase CLI
  ];

  # Sets environment variables in the workspace
  env = {
    # It's a good practice to set NODE_ENV
    NODE_ENV = "development";
  };

  idx = {
    # Search for the extensions you want on https://open-vsx.org/ and use "publisher.id"
    extensions = [
      "google.gemini-cli-vscode-ide-companion"
      "dbaeumer.vscode-eslint" # ESLint for TypeScript/JavaScript
      "esbenp.prettier-vscode" # Prettier for code formatting
      "bradlc.vscode-tailwindcss" # Tailwind CSS IntelliSense
    ];

    # Workspace lifecycle hooks
    workspace = {
      # Runs when a workspace is first created
      onCreate = {
        # Install root dependencies
        install-root-deps = "npm install";
        # Install functions dependencies
        install-functions-deps = "cd functions && npm install && cd ..";
      };
      # Runs every time the workspace is (re)started
      onStart = {
        # Start the Next.js dev server
        start-dev-server = "npm run dev";
      };
    };

    # Enable previews
    previews = {
      enable = true;
      previews = {
        web = {
          # Command to run the Next.js dev server on the correct port
          command = ["npm" "run" "dev" "--" "--port" "$PORT"];
          manager = "web";
          env = {
            # Firebase Hosting rewrites to the web preview port
            PORT = "$PORT";
          };
        };
      };
    };
  };
}
