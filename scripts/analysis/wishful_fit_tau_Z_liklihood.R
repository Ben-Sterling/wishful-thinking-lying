library(tidyverse)
library(ggplot2)
library(glue)
library(here)

# Load helper functions
source(here("scripts", "analysis", "model", "helpers.R"))

# Load data
participant_data <- read_csv(here("data", "derived", "preprocessed_participant_data.csv"))
model_data <- read_csv(here("data", "derived", "model_predictions_trials_used_all_zs.csv"))

# Define parameter grid
taus <- seq(0.01, 1, by = 0.01)
zs <- unique(model_data$z)
param_grid <- expand_grid(tau = taus, z = zs)

# Placeholder for log-likelihood results
likelihood_results <- tibble(tau = numeric(), z = numeric(), log_likelihood = numeric())

# Grid search over (tau, z)
for (i in 1:nrow(param_grid)) {
  model_z <- model_data %>% filter(z == param_grid$z[i])
  model_softmaxed <- softmax_both_models(model_z, param_grid$tau[i])
  
  combined_df <- participant_data %>%
    left_join(
      model_softmaxed %>%
        select(trial_number, utterance, Wishful_Softmaxed),
      by = c("trial_number", "utterance")
    )
  
  log_likelihood <- combined_df %>%
    summarise(log_likelihood = sum(log(Wishful_Softmaxed) * mean_response, na.rm = TRUE)) %>%
    pull(log_likelihood)
  
  likelihood_results <- likelihood_results %>%
    add_row(tau = param_grid$tau[i], z = param_grid$z[i], log_likelihood = log_likelihood)
}

# Show all results
print(likelihood_results)

# View best-fit parameters
best_params <- likelihood_results %>% filter(log_likelihood == max(log_likelihood))
print(best_params)
View(best_params)
