# luauproject-cli

A CLI tool for instantiating new Luau projects.

## Installation

### Quick Install

**macOS / Linux:**

```bash
curl -fsSL "https://raw.githubusercontent.com/horsenuggets/luauproject-cli/main/Scripts/Install.Unix.sh" | bash
```

**Windows (PowerShell):**

```powershell
iwr "https://raw.githubusercontent.com/horsenuggets/luauproject-cli/main/Scripts/Install.Win.ps1" -useb | iex
```

### Manual Install

1. Download the appropriate binary from the [releases page](https://github.com/horsenuggets/luauproject-cli/releases)
2. Run `luauproject install` to install to `~/.luauproject-cli/bin` and add to PATH

## Usage

```bash
luauproject new [flags...]
```

## Flags

All flags are optional. Without flags, prompts interactively for project name, description,
owner, and GitHub options.

| Short | Long            | If not provided   | Description                                      |
| ----- | --------------- | ----------------- | ------------------------------------------------ |
| `-n`  | `--name`        | Prompts           | Project name in kebab-case                       |
| `-d`  | `--description` | Prompts           | Project description (default: "A Luau package.") |
| `-o`  | `--owner`       | Prompts           | GitHub owner or organization                     |
| `-p`  | `--path`        | Current directory | Directory to create project in                   |
|       | `--github`      | Prompts           | Create a GitHub repository (skips confirmation)  |
|       | `--private`     | Prompts           | Create a private repository (implies `--github`) |
|       | `--nogithub`    | Prompts           | Skip GitHub repository creation                  |

## Examples

```bash
# Interactive mode
luauproject new

# Non-interactive mode (public repo)
luauproject new -n my-project -d "A cool package." -o myusername --github

# Non-interactive mode (private repo)
luauproject new -n my-project -d "A cool package." -o myusername --private

# Non-interactive mode (no GitHub repo)
luauproject new -n my-project -d "A cool package." -o myusername --nogithub

# Non-interactive with custom output directory
luauproject new -n my-project -d "A cool package." -o myusername --nogithub -p ~/projects
```
