# luauproject-cli

CLI tool to scaffold new Luau projects from [luau-package-template](https://github.com/horsenuggets/luau-package-template).

## Installation

Requires [Rokit](https://github.com/rojo-rbx/rokit) to be installed.

```bash
rokit add horsenuggets/luauproject-cli
```

## Usage

```bash
luauproject new
```

This will interactively prompt you for:
- **Project name** (kebab-case)
- **Description**
- **Author/GitHub username**
- **Create GitHub repository?**
- **Private repository?** (if creating GitHub repo)

The tool will then:
1. Clone the luau-package-template
2. Initialize a fresh git repository
3. Update project files with your details
4. Set up git submodules (claude-md-luau, luau-cicd)
5. Install Wally dependencies
6. Create initial commit

If you choose to create a GitHub repository, it will also:
- Create the repo on GitHub (public or private)
- Configure squash-only merging
- Create a protected `release` branch
- Set up branch protection rules for `main` and `release`

## Options

```bash
luauproject new --path /custom/directory
```

- `-p, --path` - Directory to create project in (default: current directory)
