terraform {
  required_version = ">= 1.0"

  required_providers {
    github = {
      source  = "integrations/github"
      version = "~> 6.0"
    }
  }
}

provider "github" {
  owner = "horsenuggets"
}

module "repo" {
  source     = "../Submodules/luau-cicd/Terraform/Modules/CommandlineCli"
  repository = "luauproject-cli"

  extra_main_checks = [
    "Test install on linux",
    "Test install on macos",
    "Test install on windows",
  ]

  extra_release_checks = [
    "Test install on linux",
    "Test install on macos",
    "Test install on windows",
  ]
}
