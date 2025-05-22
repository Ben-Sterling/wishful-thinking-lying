# This script fits tau to maximize correlation between softmaxed model predictions and mean participant responses

library(tidyverse)
library(ggplot2)
library(glue)
library(here)

source(here("scripts", "analysis", "model", "helpers.R"))

# Load data
participant_data <- read_csv(here("data", "derived", "preprocessed_participant_data.csv"))
model_data <- read_csv(here("data", "derived", "model_predictions_trials_used.csv"))

# Define tau range
taus <- seq(0.01, 1, by = 0.01)

# Store correlations for each tau
correlation_results <- data.frame(tau = numeric(),
                                  standard_cor = numeric(),
                                  wishful_cor = numeric())

# Fit tau by maximizing correlation
for (tau in taus) {
  model_data_softmaxed <- softmax_both_models(model_data, tau)

  combined_df <- participant_data %>%
    left_join(
      model_data_softmaxed %>%
        select(trial_number, utterance, Standard_Softmaxed, Wishful_Softmaxed),
      by = c("trial_number", "utterance")
    )

  correlation_results <- correlation_results %>%
    add_row(
      tau = tau,
      standard_cor = cor(combined_df$mean_response, combined_df$Standard_Softmaxed),
      wishful_cor = cor(combined_df$mean_response, combined_df$Wishful_Softmaxed)
    )
}

# Visual check
plot(correlation_results$tau, correlation_results$standard_cor, main = "Standard Correlation vs Tau")
plot(correlation_results$tau, correlation_results$wishful_cor, main = "Wishful Correlation vs Tau")

# Identify best taus
best_standard_tau <- correlation_results$tau[which.max(correlation_results$standard_cor)]
best_wishful_tau <- correlation_results$tau[which.max(correlation_results$wishful_cor)]

print(glue("Best standard tau: {best_standard_tau}"))
print(glue("Best wishful tau: {best_wishful_tau}"))

# Apply fitted taus to model predictions
models_softmaxed <- model_data %>%
  mutate(block = (row_number() - 1) %/% 3 + 1) %>%
  group_by(block) %>%
  mutate(
    Standard_Fitted_Softmaxed = multinomial_softmax(Standard_Exp, best_standard_tau),
    Wishful_Fitted_Softmaxed = multinomial_softmax(Wishful_Exp, best_wishful_tau)
  ) %>%
  ungroup()

# Clean up and export
models_cleaned <- models_softmaxed %>%
  select(
    Standard_Exp, Wishful_Exp,
    Standard_Fitted_Softmaxed, Wishful_Fitted_Softmaxed,
    trial_number, Control, utterance,
    Preference_A, Preference_B, Preference_C,
    Obs_A, Obs_B, Obs_C, obs_pref_id
  )

write_csv(models_cleaned, here("data", "derived", "models_with_fitted_taus_Exp1_fixed_omega.csv"))
