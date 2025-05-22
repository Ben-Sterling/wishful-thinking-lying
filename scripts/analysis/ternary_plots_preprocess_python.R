library(tidyverse)
library(ggtern)
library(gridExtra)
library(here)

source(here("scripts", "analysis", "model", "helpers.R"))

# Load combined model-participant data
data <- read_csv(here("data", "derived", "combined_model_participants_Exp1_fixed_omega_fixed_tau.csv"))
participant_names <- names(data %>% select(starts_with("participant_")))

# Convert preference values to strings for display
data <- data %>%
  mutate(
    Preference_A = replace_preferences_pretty(Preference_A),
    Preference_B = replace_preferences_pretty(Preference_B),
    Preference_C = replace_preferences_pretty(Preference_C)
  )

# Save the pretty-labeled version
write_csv(data, here("data", "derived", "combined_model_participants_Exp1_fixed_omega_strings_fixed_tau.csv"))

# Initialize a list to store per-trial ternary frames
trials_list <- list()

# Loop through each trial
trial_numbers <- unique(data$trial_number)
cat("Unique trial numbers:", trial_numbers, "\n")

for (current_trial in trial_numbers) {
  cat("\nProcessing trial:", current_trial, "\n")
  
  trial_df <- data %>%
    filter(trial_number == current_trial) %>%
    select(trial_number, utterance, Standard, Wishful, mean_response, all_of(participant_names))
  
  if (nrow(trial_df) == 0) {
    warning(glue("No data found for trial: {current_trial}"))
    next
  }
  
  t_trial <- t(trial_df)
  cleaned_trial <- as.data.frame(t_trial) %>%
    filter(!row.names(.) %in% c("trial_number", "utterance"))
  
  if (ncol(cleaned_trial) != 3) {
    warning(glue("Unexpected column count in trial {current_trial}"))
    next
  }
  
  colnames(cleaned_trial) <- c("Chemical A", "Chemical B", "Chemical C")
  
  cleaned_trial <- cleaned_trial %>%
    mutate(across(everything(), ~ ifelse(is.na(.), NA, round(as.numeric(.), 2)))) %>%
    rownames_to_column(var = "Participant") %>%
    mutate(
      Group = case_when(
        Participant == "Standard" ~ "Standard",
        Participant == "Wishful" ~ "Wishful",
        Participant == "mean_response" ~ "Mean Response",
        TRUE ~ "Participants"
      ),
      PointSize = if_else(Group %in% c("Standard", "Wishful", "Mean Response"), 4, 2)
    )
  
  trials_list[[paste0("Trial_", current_trial)]] <- cleaned_trial
}

# Combine into one DataFrame
combined_df <- bind_rows(trials_list, .id = "Trial")

# Save ternary-ready data
write_csv(combined_df, here("data", "derived", "trial_data_for_ternary_fixed_tau.csv"))
