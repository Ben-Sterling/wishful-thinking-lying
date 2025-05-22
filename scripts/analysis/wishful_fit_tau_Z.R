# This script fits tau and z to maximize correlation between the Wishful model and average participant judgments

library(tidyverse)
library(ggplot2)
library(glue)
library(here)

# Load helpers
source(here("scripts", "analysis", "model", "helpers.R"))

# Load data
participant_data <- read_csv(here("data", "derived", "preprocessed_participant_data.csv"))
model_data <- read_csv(here("data", "derived", "model_predictions_trials_used_all_zs.csv"))

# Define tau and z search grids
taus <- seq(0.01, 1, by = 0.01)
zs <- unique(model_data$z)
param_grid <- expand.grid(tau = taus, z = zs)

# Placeholder for correlation results
correlation_results <- tibble(tau = numeric(), z = numeric(), wishful_cor = numeric())

# Loop through all tau-z pairs
for (i in 1:nrow(param_grid)) {
  z_val <- param_grid$z[i]
  tau_val <- param_grid$tau[i]

  model_z <- model_data %>% filter(z == z_val)
  model_softmaxed <- softmax_both_models(model_z, tau_val)

  combined_df <- participant_data %>%
    left_join(
      model_softmaxed %>%
        select(trial_number, utterance, Wishful_Softmaxed),
      by = c("trial_number", "utterance")
    )

  wishful_cor <- cor(combined_df$mean_response, combined_df$Wishful_Softmaxed, use = "complete.obs")

  correlation_results <- correlation_results %>%
    add_row(tau = tau_val, z = z_val, wishful_cor = wishful_cor)
}

# Show the best parameter set
best_params <- correlation_results %>% filter(wishful_cor == max(wishful_cor, na.rm = TRUE))
print(best_params)
View(best_params)
