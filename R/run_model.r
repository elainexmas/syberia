#' Build a model using a data source from scratch.
#' 
#' @param key a string or list. If the former, there must be a
#'   file with name \code{model_stages} followed by \code{.r} so that syberia
#'   can read the model configurations.
#' @export
run_model <- function(key = get_cache('last_model') %||%
                      getOption('syberia.default_model'),
                      ..., fresh = FALSE, verbose = TRUE) {
  # TODO: Add path mechanism
  
  src_file <- NULL
  model_stages <- 
    #if (missing(key) && is.stagerunner(tmp <- active_runner())) tmp
    #if (missing(key)) get_cache('last_model')
    if (is.character(key)) {
      if (FALSE == (src_file <- normalized_filename(key)))
        stop(pp("No file for model '#{key}'"))
      source(src_file)$value
    }
    else if (is.list(key)) key
    else if (is.stagerunner(key)) key
    else stop("Invalid model key")
  
  if (is.null(src_file))
    src_file <- normalized_filename(get_cache('last_model'))

  # Coalesce the stagerunner if model file updated
  coalesce_stagerunner <- FALSE
  if (missing(key) && is.character(key) &&
      is.character(tmp <- get_cache('last_model')) && key == tmp) {
    if (!is.null(old_timestamp <- get_registry_key(
        'cached_model_modified_timestamp', get_registry_dir(src_file)))) {
      new_timestamp <- file.info(src_file)$mtime
      if (new_timestamp > old_timestamp) coalesce_stagerunner <- TRUE
    }
  }

  set_cache(key, 'last_model')
  if (!is.null(src_file))
    set_registry_key('cached_model_modified_timestamp',
                     file.info(src_file)$mtime, get_registry_dir(src_file))

  if (coalesce_stagerunner) {
    stagerunner <- construct_stage_runner(model_stages)
    stagerunner$coalesce(get_cache('last_stagerunner'))
  } else if (!missing(key) || !is.stagerunner(stagerunner <- get_cache('last_stagerunner'))) {
    stagerunner <- construct_stage_runner(model_stages)
  }

  out <- tryCatch(stagerunner$run(..., verbose = verbose),
           error = function(e) e)
  set_cache(stagerunner, 'last_stagerunner')

  if (inherits(out, 'simpleError'))
    stop(out$message)
  else out
}

