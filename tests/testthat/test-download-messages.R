test_that("download path errors give a safe next step", {
  path <- tempfile("tbod-path-file-")
  writeLines("keep this file", path)
  error <- tryCatch(.download_directory(path, resume = TRUE), error = identity)
  expect_s3_class(error, "tampa_download_error")
  expect_match(conditionMessage(error), "points to a file, not a directory")
  expect_match(conditionMessage(error), "Choose an empty directory")
  expect_identical(readLines(path), "keep this file")

  directory <- tempfile("tbod-nonempty-")
  dir.create(directory)
  note <- file.path(directory, "notes.txt")
  writeLines("keep this note", note)
  error <- tryCatch(.download_directory(directory, resume = TRUE), error = identity)
  expect_s3_class(error, "tampa_download_error")
  expect_match(conditionMessage(error), "contains unrelated files")
  expect_match(conditionMessage(error), "existing files were left unchanged")
  expect_identical(readLines(note), "keep this note")
})

test_that("unusable download paths fail before contacting the publisher", {
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http,
                        .package = "tampaBayOpenData")

  file_path <- tempfile("tbod-file-")
  writeLines("keep this file", file_path)
  expect_error(tbod_download_dataset("construction-permits", file_path),
               "points to a file", class = "tampa_download_error")
  stable_id <- paste0("arcgis:", strrep("a", 32L), ":0")
  expect_error(tbod_download_dataset(stable_id, file_path,
    portal = "https://example.org/sharing/rest"),
    "points to a file", class = "tampa_download_error")
  expect_identical(readLines(file_path), "keep this file")

  unrelated <- tempfile("tbod-unrelated-")
  dir.create(unrelated)
  note <- file.path(unrelated, "notes.txt")
  writeLines("keep this note", note)
  expect_error(tbod_download_dataset("construction-permits", unrelated),
               "contains unrelated files", class = "tampa_download_error")
  expect_identical(readLines(note), "keep this note")
  expect_false(dir.exists(file.path(unrelated, ".checkpoints")))

  saved <- tempfile("tbod-saved-")
  dir.create(saved)
  manifest <- file.path(saved, "manifest.rds")
  writeLines("keep this manifest", manifest)
  expect_error(tbod_download_dataset("construction-permits", saved,
    resume = FALSE), "resume.*FALSE", class = "tampa_download_error")
  expect_identical(readLines(manifest), "keep this manifest")
  expect_false(dir.exists(file.path(saved, ".checkpoints")))

  blocked <- tempfile("tbod-checkpoint-file-")
  dir.create(blocked)
  writeLines("saved manifest", file.path(blocked, "manifest.rds"))
  checkpoint <- file.path(blocked, ".checkpoints")
  writeLines("keep this file", checkpoint)
  expect_error(tbod_download_dataset("construction-permits", blocked),
               "checkpoint directory could not be created",
               class = "tampa_download_error")
  expect_identical(readLines(checkpoint), "keep this file")

  locked <- tempfile("tbod-locked-")
  dir.create(locked)
  lock <- file.path(locked, ".lock")
  dir.create(lock)
  expect_error(tbod_download_dataset("construction-permits", locked),
               "download directory is locked", class = "tampa_download_error")
  expect_true(dir.exists(lock))
  expect_false(dir.exists(file.path(locked, ".checkpoints")))

  ancestor <- tempfile("tbod-parent-file-")
  writeLines("keep this parent file", ancestor)
  child <- file.path(ancestor, "child")
  expect_error(tbod_download_dataset("construction-permits", child),
               "Could not create the download directory",
               class = "tampa_download_error")
  expect_identical(readLines(ancestor), "keep this parent file")
  expect_length(transport$state$requests, 0L)
})

test_that("a failed request does not create the download directory", {
  path <- tempfile("tbod-offline-")
  local_mocked_bindings(.schema_checked_layer = function(...) stop("synthetic offline"),
                        .package = "tampaBayOpenData")
  expect_error(tbod_download_dataset("construction-permits", path),
               "synthetic offline")
  expect_false(dir.exists(path))
})

test_that("damaged saved manifest explains how to recover", {
  path <- tempfile("tbod-damaged-manifest-")
  transport <- fixture_transport()
  local_mocked_bindings(arcgis_http = transport$http)
  tbod_download_dataset("construction-permits", path,
                        fields = "RECORD_ID", page_size = 2)
  writeLines("damaged manifest", file.path(path, "manifest.rds"))

  error <- tryCatch(tbod_download_dataset("construction-permits", path,
    fields = "RECORD_ID", page_size = 2), error = identity)
  expect_s3_class(error, "tampa_download_error")
  expect_match(conditionMessage(error), "saved manifest")
  expect_match(conditionMessage(error), "Restore the file or start again")
  expect_true(file.exists(file.path(path, "chunk-0000001.rds")))
})
