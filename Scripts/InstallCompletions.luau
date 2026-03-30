#!/usr/bin/env -S lune run

--[[

InstallCompletions

Installs shell completion scripts for the luauproject CLI.

--]]

local Commandline = require("@packages/Commandline")
local process = require("@lune/process")

-- Build the command tree for completion generation
local rootCommand = Commandline.Command.new({
    Name = "luauproject",
    Description = "A CLI tool for instantiating new Luau projects.",
    Subcommands = {
        Commandline.Command.new({
            Name = "install",
            Description = "Install luauproject CLI to ~/.luauproject-cli and add to PATH.",
        }),
        Commandline.Command.new({
            Name = "new",
            Description = "Create a new Luau project from template.",
            Flags = {
                Commandline.Flag.new({
                    Name = "description",
                    Shorthand = "d",
                    Description = "Project description.",
                    Type = "string",
                }),
                Commandline.Flag.new({
                    Name = "github",
                    Description = "Create a GitHub repository (skips confirmation prompt).",
                }),
                Commandline.Flag.new({
                    Name = "name",
                    Shorthand = "n",
                    Description = "Project name in kebab-case.",
                    Type = "string",
                }),
                Commandline.Flag.new({ Name = "nogithub", Description = "Skip GitHub repository creation." }),
                Commandline.Flag.new({
                    Name = "owner",
                    Shorthand = "o",
                    Description = "GitHub owner or organization.",
                    Type = "string",
                }),
                Commandline.Flag.new({
                    Name = "path",
                    Shorthand = "p",
                    Description = "Directory to create project in.",
                    Type = "string",
                }),
                Commandline.Flag.new({ Name = "private", Description = "Create a private repository." }),
                Commandline.Flag.new({
                    Name = "privatepackage",
                    Description = "Make this a private package (will not publish to Wally).",
                }),
            },
        }),
        Commandline.Command.new({
            Name = "update",
            Description = "Update luauproject CLI to the latest version.",
            Flags = {
                Commandline.Flag.new({
                    Name = "version",
                    Shorthand = "v",
                    Description = "Install a specific version instead of the latest.",
                    Type = "string",
                }),
            },
        }),
    },
})

Commandline.Toolkit.installCompletions({
    Command = rootCommand,
    Shell = process.args[1] or "zsh",
})
