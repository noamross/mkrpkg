#!/usr/bin/env Rscript

# Parse Inputs

suppressPackageStartupMessages(library("argparse"))
parser <- ArgumentParser()
parser$add_argument("pkgname", nargs = 1, help = "package name", default = NULL)
parser$add_argument("-o", "--organization", nargs = 1, help = "github organization", default = NULL)
parser$add_argument("-p", "--private", action = "store_true", help = "whether to use a private repository", default = FALSE)
parser$add_argument("-d", "--description", nargs = 1, action = "store_true", default = "What the Package Does (One Line, Title Case)")
parser$add_argument("--rstudio", help = "open the project in Rstudio", action = "store_true")
parser$add_argument("--author", help = "package author name", default = git2r::config()$global$user.name)
parser$add_argument("--email", help = "author email", default = git2r::config()$global$user.email)
parser$add_argument("--parent", help = "parent directory for project", default = options("projects.dir"))
args <- parser$parse_args()
# args <- list(pkgname = 'test', author = git2r::config()$global$user.name, email = git2r::config()$global$user.email, parent = getOption("projects.dir"))
hf <- humaniformat::parse_names(args$author)

q_na <- function(x) {
  if (is.na(x)) {
    return(x)
  } else {
    return(glue::single_quote(x))
  }
}

authors_r <- glue::glue("person({given}, {family}, {middle}, email = {email}, role = c('aut', 'cre'))",
  .na = "", given = q_na(hf$first_name), family = q_na(hf$last_name),
  middle = q_na(hf$middle_name), email = q_na(args$email)
)

if (is.null(args$pkgname)) {
  pkgdir <- getwd()
  args$pkgname <- basename(pkgdir)
} else if (is.null(args$parent)) {
  pkgdir <- file.path(getwd(), args$pkgname)
} else {
  pkgdir <- file.path(args$parent, args$pkgname)
}
pkgdir <- normalizePath(pkgdir, mustWork = FALSE)

td <- tempdir()
if (!dir.exists(td)) dir.create(td)
zpth <- file.path(td, "mkrpkg.zip")
down <- purrr::safely(download.file)("https://github.com/noamross/mkrpkg/archive/master.zip",
  destfile = zpth, quiet = TRUE)
zdir <- rappdirs::user_data_dir("mkrpkg")
if (!is.null(down$error)) {
  if (!dir.exists(zdir)) dir.create(zdir)
  file.copy(zpth, zdir, overwrite = TRUE)
}

if (!dir.exists(pkgdir)) pkgdir <- dir.create(pkgdir)

unzip(file.path(zdir, "mkrpkg.zip"), exdir = pkgdir, junkpaths = TRUE)

setwd(pkgdir)
to_rename <- normalizePath(list.files(pattern = "mkrpkg", recursive = TRUE,
                        include.dirs = TRUE, full.names = TRUE,
                        all.files = TRUE))
renamed <- gsub("mkrpkg", args$pkgname, to_rename)
file.rename(to_rename, renamed)

if()
git2r::init()
usethis::use_git_hook("pre-commit", system.file("templates", "readme-rmd-pre-commit.sh", package = "usethis"))
for (f in unlist(git2r::status(all_untracked = TRUE))) {
  x <- readLines(f)
  y <- gsub("Merry Christmas", "Happy New Year", x)
  cat(y, file = f, sep = "\n")
}

rmarkdown::render("README.Rmd")
pkgdown::build_site()
git2r::add()
git2r::commit(message = "initial commit")
gh_info <- gh::gh_tree_remote(usethis::proj_get())
codemetar::write_codemeta()
