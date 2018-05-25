#!/usr/bin/env Rscript

# Parse Inputs
if(!require(pacman)) {
  install.packages("pacman")
}
suppressPackageStartupMessages({
  pacman::p_load(
    argparse,
    humaniformat,
    glue,
    RCurl,
    gh,
    purrr,
    rappdirs,
    rmarkdown,
    pkgdown,
    codemetar,
    git2r,
    usethis)
  })
parser <- ArgumentParser()
parser$add_argument("pkgname", nargs = 1, help = "package name", default = NULL)
parser$add_argument("-o", "--organization", type="character", help = "github organization", default = NULL)
parser$add_argument("-p", "--private", action = "store_true", help = "whether to use a private repository", default = FALSE)
parser$add_argument("-d", "--description", type="character", default = "It does some stuff")
parser$add_argument("--rstudio", help = "open the project in Rstudio", action = "store_true", default = TRUE)
parser$add_argument("--author", help = "package author name", default = git2r::config()$global$user.name)
parser$add_argument("--email", help = "author email", default = git2r::config()$global$user.email)
parser$add_argument("--parent", help = "parent directory for project", default = getOption("projects.dir"))
parser$add_argument("--orcid", help = "author ORCiD", default = getOption("orcid"))
parser$add_argument("--github", help = "push to github after initializing", action = "store_true", default = FALSE)
parser$add_argument("--git", help = "create a git repository if one does not exist", action = "store_true", default = TRUE)
parser$add_argument("--pkgdown", help = "build pkgdown site", action = "store_true", default = FALSE)
parser$add_argument("--codemeta", help = "create codemeta.json", action = "store_true", default = TRUE)
args <- parser$parse_args()
# args <- list(pkgname = 'test', author = git2r::config()$global$user.name, email = git2r::config()$global$user.email, parent = getOption("projects.dir"), description = 'It does some stuff')
hf <- parse_names(args$author)

q_na <- function(x) {
  if (is.na(x)) {
    return(x)
  } else {
    return(single_quote(x))
  }
}

authors_r <- glue("person({given}, {family}, {middle}, email = {email}, role = c('aut', 'cre'){orcid})",
  .na = "", given = q_na(hf$first_name), family = q_na(hf$last_name),
  middle = q_na(hf$middle_name), email = q_na(args$email),
  orcid = ifelse(is.null(args$orcid), NA, paste0(", comment = c(ORCID='", args$orcid, "')"))
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

if(is.null(args$organization)) {
  gh_user <- getOption("github.username")
  if(is.null(gh_user)) {
    if(is.character(getURL("github.com"))) {
      gh_user <- gh_whoami()$login
    } else {
      stop("No organization specified, cannot determine GitHub username from token or getOption('github.username')")
    }
  }
} else {
  gh_user <- args$organization
}

td <- tempdir()
if (!dir.exists(td)) dir.create(td)
zpth <- file.path(td, "mkrpkg.zip")
down <- safely(download.file)("https://github.com/noamross/mkrpkg/archive/master.zip",
  destfile = zpth, quiet = TRUE)
zdir <- user_data_dir("mkrpkg")
if (is.null(down$error)) {
  if (!dir.exists(zdir)) dir.create(zdir)
  file.copy(zpth, zdir, overwrite = TRUE)
}

if (!dir.exists(pkgdir)) zz <- dir.create(pkgdir)

unzip(file.path(zdir, "mkrpkg.zip"), exdir = td, overwrite = TRUE)
file.copy(list.files(file.path(td, "mkrpkg-master"), all.files = TRUE,
                     recursive = FALSE, full.names = TRUE, include.dirs = TRUE),
          pkgdir, recursive = TRUE)
setwd(pkgdir)
mkscript <- file.path("inst", "mkrpkg.R")
if(file.exists(mkscript)) file.remove(mkscript)

to_rename <- normalizePath(list.files(pattern = "mkrpkg", recursive = TRUE,
                        include.dirs = TRUE, full.names = TRUE,
                        all.files = TRUE))
renamed <- gsub("mkrpkg", args$pkgname, to_rename)
file.rename(to_rename, renamed)

files <- list.files(all.files = TRUE, full.names=TRUE, recursive = TRUE)
files <- grep("(\\.git|\\.Rproj\\.user)/.*", files, value = TRUE, invert = TRUE)
Sys.setlocale('LC_ALL','C')
for (f in files) {
  x <- readLines(f)
  x <- gsub("{{<<PACKAGE_NAME>>}}", args$pkgname, x, fixed = TRUE)
  x <- gsub("{{<<DESCRIPTION>>}}", args$description, x, fixed = TRUE)
  x <- gsub("{{<<GH_USER>>}}", gh_user, x, fixed = TRUE)
  x <- gsub("{{<<AUTHOR>>}}", args$author, x, fixed = TRUE)
  x <- gsub("{{<<AUTHOR_EMAIL>>}}", args$email, x, fixed = TRUE)
  x <- gsub("{{<<AUTHORS_R>>}}", authors_r, x, fixed = TRUE)
  x <- gsub("{{<<YEAR>>}}", strftime(Sys.Date(), "%Y"), x, fixed = TRUE)
  cat(x, file = f, sep = "\n")
}

devtools::document()
#devtools::install()
rmarkdown::render("README.Rmd")

if(args$pkgdown) {
  pkgdown::build_site()
}

if(args$codemeta) {
  codemetar::write_codemeta()
}

if(args$git) {
  git2r::init()
  git2r::add(path = unlist(git2r::status()))
  git2r::commit(message = "Initial commit")
  usethis::use_git_hook("pre-commit", system.file("templates", "readme-rmd-pre-commit.sh", package = "usethis"))
}

if(args$github) {
  git2r::remote_add(name="origin", url = paste0("https://github.com/", gh_user, "/", args$pkgname, ".git"))
  if (is.null(args$organization)) {
    create <- gh::gh("POST /user/repos", name = args$pkgname,
                     description = args$description, private = args$private,
                     homepage = ifelse(args$pkgdown,
                                       paste0("https://", gh_user, ".github.io/", args$pkgname),
                                       NULL))
  }
  else {
    create <- gh::gh("POST /orgs/:org/repos", org = args$organization,
                     name = args$pkgname, description = args$description,
                     private = args$private,
                     homepage = ifelse(args$pkgdown,
                                       paste0("https://", gh_user, ".github.io/", args$pkgname),
                                       NULL))
  }
  git2r::branch_set_upstream(repository_head(), "master")
  git2r::push(name = "origin", refspec = "refs/heads/master",
              cred = cred_user_pass("EMAIL", gh::gh_token()))
  gh::gh("PUT /repos/:owner/:repo/topics", owner=gh_user, repo=args$pkgname,
         names = I("r"), .send_headers = c(Accept = "application/vnd.github.mercy-preview+json"))
  browseURL(desc::desc()$get_urls())

}

if(args$rstudio && Sys.info()["sysname"] == "Darwin") {
  system2(command = "open", args = paste0(args$pkgname, ".Rproj"))
}
