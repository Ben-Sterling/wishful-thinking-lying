library(tidyverse)
library(here)
library(yaml)

params <- yaml::read_yaml(here("params.yaml"))

ev_path      <- here(params$brute_force$output_file)
samples_path <- here("data", "derived", "final_samples_v5.csv")
out_path     <- here("data", "derived", "model_predictions_trials_used.csv")


#The point of this file is to take all model predictions (in expected value form) for all possible trials, then get only the ones that we are using in Exp. 1
#Requires "output_ev.csv" which has all the model predictions, and "final_samples_v5.csv" which has the selected, non-control trials.
#Outputs "model_predictions_trial_used.csv" which has model predictions as expected values for just the trials we are using.

# Load model predictions all possible trials
full_ev <- read.csv(ev_path, header = FALSE, stringsAsFactors = FALSE)

#Extract the preference values as their own df
raw_pref_range <- as.vector(full_ev[1, ])
values <- as.numeric(raw_pref_range[2:6])
names(values) <- c("HATES", "DISLIKES", "IS INDIFFERENT TO", "LIKES", "LOVES")
pref_range <- as.data.frame(as.list(values))

#Drop pref_range
colnames(full_ev) <- full_ev[2, ]
full_ev <- full_ev[-c(1, 2), ]
rownames(full_ev) <- NULL
full_ev[] <- lapply(full_ev, as.numeric)

# Calculate the transformation factors to ensure positive integers for preference score - observation pair sorting
get_transformation_factors <- function(pref_range) {
  min_value <- min(pref_range)
  max_value <- max(pref_range)
  
  multiplier <- (length(pref_range) - 1) / (max_value - min_value)
  addition <- -min_value * multiplier + 1  # Ensure the smallest value becomes 1
  
  # Return the factors as a named list
  return(list(multiplier = multiplier, addition = addition))
}

transformation_factors <- get_transformation_factors(pref_range)

#Add columns to denote preference score - observation pair for each chemical for each model prediction
full_ev <- full_ev %>% mutate(
  Preference_A_alt = Preference_A * transformation_factors$multiplier + transformation_factors$addition,
  Preference_B_alt = Preference_B * transformation_factors$multiplier + transformation_factors$addition,
  Preference_C_alt = Preference_C * transformation_factors$multiplier + transformation_factors$addition,
  obs_pref_idA = as.numeric(paste0(Obs_A, Preference_A_alt)),
  obs_pref_idB = as.numeric(paste0(Obs_B, Preference_B_alt)),
  obs_pref_idC = as.numeric(paste0(Obs_C, Preference_C_alt))
) 

#Sort the pref - obs pairs and create a unique pref-obs pairs id for each unique set of three pairs
full_ev <- full_ev %>% rowwise() %>%
  mutate(
    obs_pref_id = paste(max(c(obs_pref_idA, obs_pref_idB, obs_pref_idC)), 
                        median(c(obs_pref_idA, obs_pref_idB, obs_pref_idC)), 
                        min(c(obs_pref_idA, obs_pref_idB, obs_pref_idC)))
  )

#There 5*6=30 possible pairings of evidence and preference for a single chemical
#There's 30 choose 3 with replacement ways to order those pairings for 3 chemicals
#We expect 4960 distinct ids for 4960 unique pref-obs pair sets
n_distinct(full_ev$obs_pref_id)

full_ev <- full_ev %>%
  group_by(obs_pref_id) %>%
  mutate(config_group = cur_group_id()) %>%
  ungroup()

trials_used <- read.csv(samples_path)

retrieve_sampled_rows <- function(data, sampled_configs) {
  sampled_rows <- list()
  
  for (i in seq_len(nrow(sampled_configs))) {
    # Extract the current row from sampled_configs
    sampled_row <- sampled_configs[i, ]
    
    for (utterance_value in 0:2) {
      # Find matching rows in data for the current utterance value
      matching_row <- data %>%
        filter(
          utterance == utterance_value,
          Preference_A == sampled_row$Preference_A,
          Preference_B == sampled_row$Preference_B,
          Preference_C == sampled_row$Preference_C,
          Obs_A == sampled_row$Obs_A,
          Obs_B == sampled_row$Obs_B,
          Obs_C == sampled_row$Obs_C,
          
        )
      
      # Check if there are multiple or no matches
      if (nrow(matching_row) != 1) {
        stop(
          paste("Error: Expected exactly 1 match for row", i, "in sampled_configs but found", nrow(matching_row), "matches.")
        )
      }
      
      # Append the single matching row to the list
      sampled_rows[[length(sampled_rows) + 1]] <- matching_row
    }
  }
  
  # Combine all matching rows into a single dataframe
  do.call(rbind, sampled_rows)
}

trials_ev <- retrieve_sampled_rows(full_ev, trials_used)

control_data <- tibble(
  trial_number = 1:2,  # Define trial numbers
  Preference_A = c(0, 0),
  Preference_B = c(0, 0),
  Preference_C = c(0, 0),
  Obs_A = c(5, 1),
  Obs_B = c(3, 0),
  Obs_C = c(4, 2),
  Standard = NA,
  Wishful = NA  # Wishful column is NA for trials 1-5
)

controls_ev <- retrieve_sampled_rows(full_ev, control_data)

trials_ev <- rbind(controls_ev, trials_ev)

trial_range <- 1:32

trials_ev <- trials_ev %>%
  mutate(trial_number = rep(trial_range, each = 3)) %>% # Repeat trial numbers for each utterance (3 per trial)
  select(trial_number, utterance, Standard, Wishful, Preference_A, Preference_B, Preference_C,
         Obs_A, Obs_B, Obs_C, obs_pref_id)
trials_ev <- trials_ev %>% rename(Standard_Exp = Standard, Wishful_Exp = Wishful) %>% mutate(Control = trial_number<3)

write.csv(trials_ev, out_path, row.names = FALSE)