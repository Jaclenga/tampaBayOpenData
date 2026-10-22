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
