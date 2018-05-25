#!/usr/bin/env Rscript

# Parse Inputs

suppressPackageStartupMessages(library("argparse"))
suppressPackageStartupMessages(library("usethis"))
parser <- ArgumentParser()
parser$add_argument("pkgname", nargs=1, help="package name")
parser$add_argument("-o", "--organization", nargs=1, help="github organization", default = NULL)
parser$add_argument("-p", "--private", action="store_true", help = "whether to use a private repository", default = FALSE)
parser$add_argument("-d", "--description", action="store_true", default = "What the Package Does (One Line, Title Case)")
parser$add_argument("--rstudio", help = "open the project in Rstudio", default = TRUE)
parser$add_argument("--ci", help='which CI system to use, can be "travis", "circle", or "none"', default = "circle")
args <- parser$parse_args()

options(
  usethis.name = "Noam Ross",
  usethis.description = list(
    `Authors@R` = 'person("Noam", "Ross", email = "noam.ross@gmail.ocom", role = c("aut", "cre"))',
    License = "MIT + file LICENSE",
    Version = "0.0.0.9000",
    Title = args$description,
    Description = args$description

  )
)

create_package(args$pkgname)
usethis::use_readme_rmd()
usethis::use_roxygen_md()
usethis::use_mit_license()
usethis::use_package_doc()
usethis::use_description()
#usethis::use_badge("License: MIT", src="https://img.shields.io/badge/License-MIT-yellow.svg",
#                   href = "https://opensource.org/licenses/MIT")
#usethis::use_badge("CircleCI", src="https://circleci.com/gh/ecohealthalliance/lemis.svg",
#                   href = "https://circleci.com/gh/ecohealthalliance/lemis")

usethis::use_vignette(args$pkgname)

usethis::use_git()
usethis::use_github_links()
usethis::use_github(organization = args$organization, private = args$private)
