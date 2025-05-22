library(tidyverse)
library(here)
library(yaml)
source(here("model", "helpers.R"))

params <- read_yaml(here("params.yaml"))

zs_path   <- here(params$z_sampling$ev_combined_file)
z4_path   <- here(params$z_sampling$z4_file)
used_path <- here(params$z_sampling$trials_used_file)
out_path  <- here(params$z_sampling$output_file)


#The point of this file is to take all model predictions (in expected value form) for all possible trials, then get only the ones that we are using in Exp. 1
#Requires "data_all_zs.csv" which has all the model predictions in EV form and all Zs, and "final_samples_v5.csv" which has the selected, non-control trials.
#Outputs "model_predictions_all_z_trial_used.csv" which has model predictions as expected values for just the trials we are using.

# Load model predictions all possible trials
#zs_coarse <- read.csv("model/model_predictions/data_all_zs_coarse.csv")
#zs <- read.csv("model/model_predictions/data_all_zs.csv")
#zs_old <- read.csv("model/model_predictions/data_all_zs_old_script.csv")
zs <- read.csv(zs_path)
z4 <- read.csv(z4_path)
zs_total <- rbind(zs, z4)

#Load trials used. Even tho these have model predictions, we aren't using those.
trials_used <- read.csv(used_path)
# Apply the function to the Preference columns
trials_used <- trials_used %>%
  mutate(
    Preference_A = replace_preferences(Preference_A),
    Preference_B = replace_preferences(Preference_B),
    Preference_C = replace_preferences(Preference_C)
  ) %>% select(-Standard_Exp, -Wishful_Exp)

models <- merge(trials_used, zs_total, 
              by=c("Preference_A", "Preference_B", "Preference_C", 
                   "Obs_A", "Obs_B", "Obs_C", "utterance"))
models <- models %>% rename(Standard_Exp = Standard, Wishful_Exp = Wishful)

write.csv(models, out_path, row.names = FALSE)