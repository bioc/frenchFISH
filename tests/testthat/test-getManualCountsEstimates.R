context("Testing manual spot counting correction")

cell_radius = 8
section_height = 4
manual_counts = cbind(red = c(0, 2, 4),
                      green = c(5, 3, 1),
                      blue = c(3, 0, 2))
manual_counts_estimates <- getManualCountsEstimates(manual_counts, cell_radius, section_height)

test_that("getManualCountsEstimates function works", {
  expect_true(is.data.frame(manual_counts_estimates))
  expect_equal(dim(manual_counts_estimates), c(3, 6))
  expect_equal(toString(manual_counts_estimates$Probe), c("red, green, blue"))

  # Can't test exact value because of non-determinism
  #expect_equal(round(manual_counts_estimates$X2.5), c(2, 4, 2))
  #expect_equal(round(manual_counts_estimates$X25, 3), c(5.895, 4.211, 2.526))
  #expect_equal(round(manual_counts_estimates$X50, 3), c(12.365, 10.116, 7.833))
  #expect_equal(round(manual_counts_estimates$X75, 3), c(12.365, 10.116, 7.833))
  #expect_equal(round(manual_counts_estimates$X97.5, 3), c(12.365, 10.116, 7.833))
})

test_that("getManualCountsEstimates function throws error messages when input arguments are invalid", {
  expect_error(getManualCountsEstimates(automatic_counts, "radius", 4), "radius must be numeric")
  expect_error(getManualCountsEstimates(automatic_counts, NA, 4), "radius must be numeric")
  expect_error(getManualCountsEstimates(automatic_counts, 8, "height"), "height must be numeric")
  expect_error(getManualCountsEstimates(automatic_counts, 8, NA), "height must be numeric")
  expect_error(getManualCountsEstimates(automatic_counts, -8, 4), "radius must be greater than 0")
  expect_error(getManualCountsEstimates(automatic_counts, 8, -4), "height must be greater than 0")
  expect_error(getManualCountsEstimates("probeCounts", 8, 4), "probeCounts must be a matrix")
  expect_error(getManualCountsEstimates(5, 8, 4), "probeCounts must be a matrix")
  expect_error(getAutomaticCountsEstimates(matrix(NA, nrow = 0, ncol = 0), 8, 4), "probeCounts must have at least one row")
  #expect_error(getManualCountsEstimates(cbind(red=c(NA)), 8, 4), "probeCounts cannot have any NA or NaN values")
  #expect_error(getManualCountsEstimates(cbind(red=c(NaN)), 8, 4), "probeCounts cannot have any NA or NaN values")
  #expect_error(getManualCountsEstimates(cbind(red=c(Inf)), 8, 4), "probeCounts cannot have any Inf or -Inf values")
  expect_error(getManualCountsEstimates(cbind(red=c(-Inf)), 8, 4), "probeCounts cannot have any Inf or -Inf values")
  expect_error(getManualCountsEstimates(cbind(red=c(1.5)), 8, 4), "All non-NA/NaN counts in probeCounts must be non-negative integers")
  expect_error(getManualCountsEstimates(cbind(red=c(-1)), 8, 4), "All non-NA/NaN counts in probeCounts must be non-negative integers")
  expect_error(getManualCountsEstimates(cbind(red=c(-1.5)), 8, 4), "All non-NA/NaN counts in probeCounts must be non-negative integers")
  expect_warning(getManualCountsEstimates(cbind(red=c(0)), 8, 4), "All non-NA/NaN counts of red probe are 0. Estimated count for this probe may not be accurate")
  expect_warning(getManualCountsEstimates(cbind(red=c(NA)), 8, 4), "All counts of red probe are NA or NaN. Estimated count will be NA")
})
