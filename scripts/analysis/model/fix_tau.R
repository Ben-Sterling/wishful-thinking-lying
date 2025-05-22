library(tidyverse)
library(ggplot2)
library(glue)
library(here)

source(here("scripts", "analysis", "model", "helpers.R"))

tau <- 0.1

# Load data
participant_data <- read_csv(here("data", "derived", "preprocessed_participant_data.csv"))
model_data <- read_csv(here("data", "derived", "model_predictions_trials_used.csv"))

# Apply softmax to blocks of 3 rows each
models_softmaxed <- model_data %>%
  mutate(block = (row_number() - 1) %/% 3 + 1) %>%
  group_by(block) %>%
  mutate(
    Standard_Fitted_Softmaxed = multinomial_softmax(Standard_Exp, tau),
    Wishful_Fitted_Softmaxed = multinomial_softmax(Wishful_Exp, tau)
  ) %>%
  ungroup()

# Clean and reorder columns
models_cleaned <- models_softmaxed %>%
  select(
    Standard_Exp, Wishful_Exp,
    Standard_Fitted_Softmaxed, Wishful_Fitted_Softmaxed,
    trial_number, Control, utterance,
    Preference_A, Preference_B, Preference_C,
    Obs_A, Obs_B, Obs_C, obs_pref_id
  )

# Write to file
write_csv(models_cleaned, here("data", "derived", "models_with_fixed_tau_Exp1_fixed_omega.csv"))
