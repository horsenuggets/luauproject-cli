#!/bin/bash

#
# mock-gh.sh
#
# This script simulates the gh CLI for testing luauproject-cli. For repo clone, it
# actually clones from GitHub to stay in sync with the real template. For other commands
# that require authentication (repo create, api calls, secrets), it mocks the behavior.
#

case "$1" in
    "auth")
        echo "Logged in as test-user"
        exit 0
        ;;

    "api")
        if [[ "$2" == "user" ]]; then
            # Return username for --jq .login
            echo "test-user"
        elif [[ "$2" == "user/orgs" ]]; then
            # Return empty orgs list
            echo ""
        elif [[ "$2" == repos/* ]]; then
            # API calls to repos (settings, branch protection, etc.)
            echo "{}"
        else
            echo "{}"
        fi
        exit 0
        ;;

    "repo")
        if [[ "$2" == "clone" ]]; then
            # $3 is the repo (horsenuggets/luau-package-template)
            # $4 is the destination path
            # Remaining args after -- are passed to git clone
            REPO="$3"
            DEST="$4"

            # Use git clone directly to stay in sync with the real template
            git clone "https://github.com/$REPO.git" "$DEST" --depth=1 2>&1
            exit $?

        elif [[ "$2" == "create" ]]; then
            # Parse arguments to find --source and repo name
            REPO_NAME="$3"
            SOURCE_DIR=""
            SHOULD_PUSH=false

            shift 3  # Skip 'repo create <name>'
            while [[ $# -gt 0 ]]; do
                case "$1" in
                    --source)
                        SOURCE_DIR="$2"
                        shift 2
                        ;;
                    --push)
                        SHOULD_PUSH=true
                        shift
                        ;;
                    *)
                        shift
                        ;;
                esac
            done

            echo "Created repository $REPO_NAME"

            # Set up git remote in the source directory
            if [[ -n "$SOURCE_DIR" && -d "$SOURCE_DIR" ]]; then
                cd "$SOURCE_DIR"
                git remote add origin "https://github.com/$REPO_NAME.git" 2>/dev/null || true

                if $SHOULD_PUSH; then
                    echo "Pushed to origin"
                fi
            fi

            exit 0
        fi
        ;;

    "secret")
        echo "Secret set"
        exit 0
        ;;

    *)
        echo "Mock gh: $@"
        exit 0
        ;;
esac
