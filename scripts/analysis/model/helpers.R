#Contains helper functions for processing model predictions

## Define a function to replace numeric values with corresponding strings
replace_preferences <- function(x) {
  case_when(
    x == -1.0 ~ "hates",
    x == -0.5 ~ "dislikes",
    x == 0.0 ~ "is indifferent to",
    x == 0.5 ~ "likes",
    x == 1.0 ~ "loves",
    TRUE ~ as.character(x)  # Keep other values as they are
  )
}

replace_preferences_pretty <- function(x) {
  case_when(
    x == -1.0 ~ "HATE",
    x == -0.5 ~ "DISLIKE",
    x == 0.0 ~ "INDIFF",
    x == 0.5 ~ "LIKE",
    x == 1.0 ~ "LOVE",
    TRUE ~ as.character(x)  # Keep other values as they are
  )
}

###############################################################################
#Having to do with softmaxing

# Define log_softmax function
log_softmax <- function(values, tau) {
  max_val <- max(values)  # Avoid numerical overflow
  (1 / tau) * (values - max_val)  # Scale and shift by max value
}

# Define multinomial_softmax function
multinomial_softmax <- function(values, tau) {
  log_values <- log_softmax(values, tau)  # Apply log-softmax
  exp_values <- exp(log_values)  # Exponentiate
  exp_values / sum(exp_values)  # Normalize to sum to 1
}

# Apply softmax with tau to both standard and wishful models
softmax_both_models <- function(model_data, tau){
  model_data_softmaxed <- model_data %>%
    mutate(block = (row_number() - 1) %/% 3 + 1) %>%
    group_by(block) %>%
    mutate(Standard_Softmaxed = multinomial_softmax(Standard_Exp, tau),
           Wishful_Softmaxed = multinomial_softmax(Wishful_Exp, tau)) %>%
    ungroup()
}

##############################################################################

calculate_correlations <- function(model_column, participant_columns, data, range) {
  correlations <- sapply(participant_columns, function(participant_col) {
    cor.test(data[[model_column]][range], data[[participant_col]][range])$estimate
  })
  names(correlations) <- participant_columns
  correlations
}
