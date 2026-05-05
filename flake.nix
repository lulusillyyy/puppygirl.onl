{
  description = "Hugo site with Flake-based dev and deploy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };
        
        deployScript = pkgs.writeShellApplication {
          name = "deploy-site";
          runtimeInputs = with pkgs; [ hugo rsync openssh ]; # Added openssh for rsync
          text = ''
            # We use ''${} so Nix doesn't try to evaluate these as Nix variables
            SERVER_USER="''${DEPLOY_SERVER_USER:-}"
            SERVER_IP="''${DEPLOY_SERVER_IP:-}"
            REMOTE_PATH="''${DEPLOY_REMOTE_PATH:-}"

            # Basic validation
            if [ -z "$SERVER_USER" ] || [ -z "$SERVER_IP" ] || [ -z "$REMOTE_PATH" ]; then
              echo "Error: Deployment environment variables are not set."
              echo "Ensure DEPLOY_SERVER_USER, DEPLOY_SERVER_IP, and DEPLOY_REMOTE_PATH are in your .env file."
              exit 1
            fi

            echo "Building Hugo site..."
            hugo --minify

            echo "Hugo build successful. Syncing files to server..."
            # Using -e ssh ensures rsync knows how to connect
            rsync -avz --delete public/ "$SERVER_USER@$SERVER_IP:$REMOTE_PATH"
            
            echo "Deployment complete!"
          '';
      }; 
      in
      {
        # Development environment
        devShells.default = pkgs.mkShell {
          buildInputs = [ pkgs.hugo deployScript ];
        };

        # Allows running 'nix run .#deploy'
        apps.deploy = {
          type = "app";
          program = "${deployScript}/bin/deploy-site";
        };
      });
}
