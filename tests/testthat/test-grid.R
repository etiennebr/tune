context("grid search")

# ------------------------------------------------------------------------------

source(test_path("../helper-objects.R"))

# ------------------------------------------------------------------------------

rec_tune_1 <-
  recipe(mpg ~ ., data = mtcars) %>%
  step_normalize(all_predictors()) %>%
  step_pca(all_predictors(), num_comp = tune())

rec_no_tune_1 <-
  recipe(mpg ~ ., data = mtcars) %>%
  step_normalize(all_predictors())

lm_mod <- linear_reg() %>% set_engine("lm")

svm_mod <- svm_rbf(mode = "regression", cost = tune()) %>% set_engine("kernlab")

# ------------------------------------------------------------------------------

test_that('tune recipe only', {

  set.seed(4400)
  wflow <- workflow() %>% add_recipe(rec_tune_1) %>% add_model(lm_mod)
  pset <- dials::parameters(wflow) %>% update(num_comp = num_comp(c(1, 3)))
  grid <- grid_regular(pset, levels = 3)
  folds <- vfold_cv(mtcars)
  res <- tune_grid(wflow, resamples = folds, grid = grid)
  expect_equal(res$id, folds$id)
  res_est <- collect_metrics(res)
  expect_equal(nrow(res_est), nrow(grid) * 2)
  expect_equal(sum(res_est$.metric == "rmse"), nrow(grid))
  expect_equal(sum(res_est$.metric == "rsq"), nrow(grid))
  expect_equal(res_est$n, rep(10, nrow(grid) * 2))
})

# ------------------------------------------------------------------------------

test_that('tune model only (with recipe)', {

  set.seed(4400)
  wflow <- workflow() %>% add_recipe(rec_no_tune_1) %>% add_model(svm_mod)
  pset <- dials::parameters(wflow)
  grid <- grid_regular(pset, levels = 3)
  folds <- vfold_cv(mtcars)
  res <- tune_grid(wflow, resamples = folds, grid = grid)
  expect_equal(res$id, folds$id)
  res_est <- collect_metrics(res)
  expect_equal(nrow(res_est), nrow(grid) * 2)
  expect_equal(sum(res_est$.metric == "rmse"), nrow(grid))
  expect_equal(sum(res_est$.metric == "rsq"), nrow(grid))
  expect_equal(res_est$n, rep(10, nrow(grid) * 2))
})

# ------------------------------------------------------------------------------

test_that('tune model only (with recipe, multi-predict)', {

  set.seed(4400)
  wflow <- workflow() %>% add_recipe(rec_no_tune_1) %>% add_model(svm_mod)
  pset <- dials::parameters(wflow)
  grid <- grid_regular(pset, levels = 3)
  folds <- vfold_cv(mtcars)
  res <- tune_grid(wflow, resamples = folds, grid = grid)
  expect_equal(res$id, folds$id)
  expect_equal(
    colnames(res$.metrics[[1]]),
    c("cost", ".metric", ".estimator", ".estimate")
  )
  res_est <- collect_metrics(res)
  expect_equal(nrow(res_est), nrow(grid) * 2)
  expect_equal(sum(res_est$.metric == "rmse"), nrow(grid))
  expect_equal(sum(res_est$.metric == "rsq"), nrow(grid))
  expect_equal(res_est$n, rep(10, nrow(grid) * 2))
})

# ------------------------------------------------------------------------------

test_that('tune model and recipe', {

  set.seed(4400)
  wflow <- workflow() %>% add_recipe(rec_tune_1) %>% add_model(svm_mod)
  pset <- dials::parameters(wflow) %>% update(num_comp = num_comp(c(1, 3)))
  grid <- grid_regular(pset, levels = 3)
  folds <- vfold_cv(mtcars)
  res <- tune_grid(wflow, resamples = folds, grid = grid)
  expect_equal(res$id, folds$id)
  expect_equal(
    colnames(res$.metrics[[1]]),
    c("cost", "num_comp", ".metric", ".estimator", ".estimate")
  )
  res_est <- collect_metrics(res)
  expect_equal(nrow(res_est), nrow(grid) * 2)
  expect_equal(sum(res_est$.metric == "rmse"), nrow(grid))
  expect_equal(sum(res_est$.metric == "rsq"), nrow(grid))
  expect_equal(res_est$n, rep(10, nrow(grid) * 2))
})

# ------------------------------------------------------------------------------

test_that('tune model and recipe (multi-predict)', {

  set.seed(4400)
  wflow <- workflow() %>% add_recipe(rec_tune_1) %>% add_model(svm_mod)
  pset <- dials::parameters(wflow) %>% update(num_comp = num_comp(c(2, 3)))
  grid <- grid_regular(pset, levels = c(3, 2))
  folds <- vfold_cv(mtcars)
  res <- tune_grid(wflow, resamples = folds, grid = grid)
  expect_equal(res$id, folds$id)
  res_est <- collect_metrics(res)
  expect_equal(nrow(res_est), nrow(grid) * 2)
  expect_equal(sum(res_est$.metric == "rmse"), nrow(grid))
  expect_equal(sum(res_est$.metric == "rsq"), nrow(grid))
  expect_equal(res_est$n, rep(10, nrow(grid) * 2))
})

# ------------------------------------------------------------------------------

test_that("tune recipe only - failure in recipe is caught elegantly", {

  set.seed(7898)
  data_folds <- vfold_cv(mtcars, v = 2)

  rec <- recipe(mpg ~ ., data = mtcars) %>%
    step_bs(disp, deg_free = tune())

  model <- linear_reg(mode = "regression") %>%
    set_engine("lm")

  # NA values not allowed in recipe
  cars_grid <- tibble(deg_free = c(3, NA_real_, 4))

  # ask for predictions and extractions
  control <- control_grid(
    save_pred = TRUE,
    extract = function(x) 1L
  )

  cars_res <- tune_grid(
    model,
    preprocessor = rec,
    resamples = data_folds,
    grid = cars_grid,
    control = control
  )

  notes <- cars_res$.notes
  note <- notes[[1]]$.notes

  extract <- cars_res$.extracts[[1]]

  predictions <- cars_res$.predictions[[1]]
  used_deg_free <- sort(unique(predictions$deg_free))

  expect_length(notes, 2L)

  # failing rows are not in the output
  expect_equal(nrow(extract), 2L)
  expect_equal(extract$deg_free, c(3, 4))

  expect_equal(used_deg_free, c(3, 4))
})

test_that("tune model only - failure in recipe is caught elegantly", {

  set.seed(7898)
  data_folds <- vfold_cv(mtcars, v = 2)

  # NA values not allowed in recipe
  rec <- recipe(mpg ~ ., data = mtcars) %>%
    step_bs(disp, deg_free = NA_real_)

  cars_grid <- tibble(cost = c(0.01, 0.02))

  expect_warning(
    cars_res <- tune_grid(
      svm_mod,
      preprocessor = rec,
      resamples = data_folds,
      grid = cars_grid,
      control = control_grid(extract = function(x) {1}, save_pred = TRUE)
    ),
    "All models failed"
  )

  notes <- cars_res$.notes
  note <- notes[[1]]$.notes

  extracts <- cars_res$.extracts
  predictions <- cars_res$.predictions

  expect_length(notes, 2L)

  # recipe failed - no models run
  expect_equal(extracts, list(NULL, NULL))
  expect_equal(predictions, list(NULL, NULL))
})

test_that("tune model only - failure in formula is caught elegantly", {

  set.seed(7898)
  data_folds <- vfold_cv(mtcars, v = 2)

  cars_grid <- tibble(cost = 0.01)

  # these terms don't exist!
  expect_warning(
    cars_res <- tune_grid(
      svm_mod,
      y ~ z,
      resamples = data_folds,
      grid = cars_grid,
      control = control_grid(extract = function(x) {1}, save_pred = TRUE)
    ),
    "All models failed"
  )

  notes <- cars_res$.notes
  note <- notes[[1]]$.notes

  extracts <- cars_res$.extracts
  predictions <- cars_res$.predictions

  expect_length(notes, 2L)

  # formula failed - no models run
  expect_equal(extracts, list(NULL, NULL))
  expect_equal(predictions, list(NULL, NULL))
})

test_that("tune model and recipe - failure in recipe is caught elegantly", {

  set.seed(7898)
  data_folds <- vfold_cv(mtcars, v = 2)

  rec <- recipe(mpg ~ ., data = mtcars) %>%
    step_bs(disp, deg_free = tune())


  # NA values not allowed in recipe
  cars_grid <- tibble(deg_free = c(NA_real_, 10L), cost = 0.01)

  cars_res <- tune_grid(
    svm_mod,
    preprocessor = rec,
    resamples = data_folds,
    grid = cars_grid,
    control = control_grid(extract = function(x) {1}, save_pred = TRUE)
  )

  notes <- cars_res$.notes
  note <- notes[[1]]$.notes

  extract <- cars_res$.extracts[[1]]
  prediction <- cars_res$.predictions[[1]]

  expect_length(notes, 2L)

  # recipe failed half of the time, only 1 model passed
  expect_equal(nrow(extract), 1L)
  expect_equal(extract$deg_free, 10L)
  expect_equal(extract$cost, 0.01)

  expect_equal(
    unique(prediction[, c("deg_free", "cost")]),
    tibble(deg_free = 10, cost = 0.01)
  )
})

test_that("argument order gives warning for recipes", {
  expect_warning(
    tune_grid(rec_tune_1, lm_mod, vfold_cv(mtcars, v = 2)),
    "is deprecated as of lifecycle"
  )
})

test_that("argument order gives warning for formula", {
  expect_warning(
    tune_grid(mpg ~ ., lm_mod, vfold_cv(mtcars, v = 2)),
    "is deprecated as of lifecycle"
  )
})

test_that("ellipses with tune_grid", {

  wflow <- workflow() %>% add_recipe(rec_tune_1) %>% add_model(lm_mod)
  folds <- vfold_cv(mtcars)
  expect_warning(
    tune_grid(wflow, resamples = folds, grid = 3, something = "wrong"),
    "The `...` are not used in this function but one or more objects"
  )
})
