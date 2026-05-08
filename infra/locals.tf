locals {
  source_path = abspath("${path.module}/../backend")
  docker_file = "Dockerfile.lambda"

  # Include only files that affect the Lambda image/runtime behavior.
  path_include = [
    "Dockerfile.lambda",
    "requirements.txt",
    "alembic.ini",
    "app/**/*.py",
    "alembic/**/*.py",
  ]

  files_include = sort(setunion([for pattern in local.path_include : fileset(local.source_path, pattern)]...))
  code_hash     = sha1(join("", [for f in local.files_include : filesha1("${local.source_path}/${f}")]))
}
