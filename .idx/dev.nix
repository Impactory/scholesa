
{ pkgs, ... }: {
  packages = [ pkgs.nodejs_20 ];
  idx = {
    extensions = [ "dbaeumer.vscode-eslint" ];
    previews = {
      enable = true;
      previews = {
        web = {
          command = ["npx" "http-server" "-p" "$PORT"];
          manager = "web";
        };
      };
    };
  };
}
