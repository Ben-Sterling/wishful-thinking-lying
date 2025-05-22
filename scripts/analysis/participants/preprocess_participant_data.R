#Script for pre-processing participant data from Qualtrics
library(tidyverse)
library(here)
library(yaml)

params <- read_yaml(here("params.yaml"))
participant_data <- read_csv(here(params$preprocessing$input_file))

############################
#Define helper functions

# Convert string like ["82","9","9"] into a numeric vector
convert_to_numeric_vector <- function(x) {
  # Remove square brackets and quotes, then split by commas
  values <- gsub("\\[|\\]|\"", "", x) %>%
    strsplit(",") %>%
    unlist()
  # Convert the character values to numeric
  as.numeric(values)
}

#This is a helper function that , when applied to a "long" dataframe where each row is a participant, each column is a trial,
#and responses are in a "responses" column consisting of vectors, processes the data so that
#each row is the utterance for a trial (resulting in three rows per trial) and participants are columns
process <- function(long_data){
  long_data <- long_data %>%
    mutate(
      responses = lapply(responses, function(x) if (is.null(x)) NA else x)
    ) %>%
    unnest_longer(responses)
  
  long_data <- long_data %>%
    group_by(trial_column, ProlificID) %>%
    mutate(
      trial_number = as.numeric(gsub("\\D", "", trial_column)), # Extract trial number
      utterance = (row_number() - 1) %% 3,                     # Generate utterance values (0, 1, 2)
      participant_id = paste0("participant_", substr(ProlificID, 1, 6)) # Unique participant ID
    ) %>%
    ungroup()
  
  long_data <- long_data %>% select(-ProlificID)
  
  wide_data <- long_data %>%
    pivot_wider(
      names_from = participant_id,   # Use unique participant ID as column names
      values_from = responses        # Populate columns with responses
    )
  
  wide_data <- wide_data %>%
    mutate(across(starts_with("participant_"), ~ . / 100))
  
  # Calculate the mean response for participant columns
  wide_data <- wide_data %>%
    rowwise() %>%
    mutate(mean_response = mean(c_across(starts_with("participant_")), na.rm = TRUE)) %>%
    ungroup()
}

############################
#Attention checks

#Select only only attention check trials
attention_columns <- grep("^attention\\d+_triangle$", colnames(participant_data), value = TRUE)
attention_checks <- participant_data %>%
  select(ProlificID, all_of(attention_columns))

# Apply the conversion function to all triangle columns
for (col in attention_columns) {
  # Convert the string values to numeric vectors
  attention_checks[[col]] <- lapply(attention_checks[[col]], convert_to_numeric_vector)
}

long_data <- attention_checks %>%
  pivot_longer(
    cols = starts_with("attention"),
    names_to = "trial_column",
    values_to = "responses"
  )

attention <- process(long_data)

long_attention <- attention %>% pivot_longer(starts_with("participant"), names_to = "participant_id", values_to = "responses") %>%
  select(-trial_number, -mean_response)

#Attention check one. Answer is Chemical A / utterance 0
attention1 <- long_attention %>% filter(trial_column=="attention1_triangle", utterance==0) %>% mutate(attention_check_1_passed = responses > 0.75) %>%
  select(participant_id, attention_check_1_passed)
#Attention check two. Answer is Chemical B
attention2 <- long_attention %>% filter(trial_column=="attention2_triangle", utterance==1) %>% mutate(attention_check_2_passed = responses > 0.75) %>%
  select(participant_id, attention_check_2_passed)
#Attention check three. Answer is 33-33-33
attention3 <- long_attention %>% filter(trial_column=="attention3_triangle") %>% mutate(attention_check_3_partly_passed = (responses > 1/6 & responses < 3/6)) %>%
  select(participant_id, utterance, attention_check_3_partly_passed) %>% pivot_wider(names_from = utterance, values_from = attention_check_3_partly_passed) %>%
  mutate(attention_check_3_passed = if_all(c(`0`, `1`, `2`), ~ .x == TRUE)) %>% select(participant_id, attention_check_3_passed)
#Attention check four. Answer is Chemical C
attention4 <- long_attention %>% filter(trial_column=="attention4_triangle", utterance==2) %>% mutate(attention_check_4_passed = responses > 0.75) %>%
  select(participant_id, attention_check_4_passed)

attention_checks <- list(attention1, attention2, attention3, attention4)
merged_attention_checks <- reduce(attention_checks, full_join, by = "participant_id")
attention_counts <- merged_attention_checks %>% mutate(how_many_passed = rowSums(select(., attention_check_1_passed, attention_check_2_passed, attention_check_3_passed, attention_check_4_passed) == TRUE)) %>%
  select(participant_id, how_many_passed) %>% mutate(passed = how_many_passed >= 3)

#see if any participants failed more than one attention check
attention_counts %>% filter(passed == FALSE)

#remove participants who failed attention checks from participant data
participants_who_passed <- attention_counts %>%
  filter(passed == TRUE) %>%
  pull(participant_id)

participant_data <- participant_data %>%
  filter(paste0("participant_", substr(ProlificID, 1, 6)) %in% participants_who_passed)

###############
#Check self-reported attention
participant_data <- participant_data %>% rename(self_reported_attention = attention_4)
participant_data$self_reported_attention = as.numeric(participant_data$self_reported_attention)
participant_data %>% select(ProlificID, self_reported_attention) %>% 
  mutate(inattentive = self_reported_attention < 90) %>%
  filter(inattentive==TRUE)

# Display the count of attentive participants
participant_data %>% 
  mutate(inattentive = self_reported_attention < 90) %>% 
  count(!inattentive) %>% 
  print()

# Filter out inattentive participants
participant_data <- participant_data %>% 
  mutate(inattentive = self_reported_attention < 90) %>% 
  filter(inattentive == FALSE)

participant_data <- participant_data %>% select(-inattentive)

###############
#Continue pre-processing

# Select only columns of the format trial##_triangle
triangle_columns <- grep("^trial\\d+_triangle$", colnames(participant_data), value = TRUE)
result <- participant_data %>%
  select(ProlificID, all_of(triangle_columns))

# Apply the conversion function to all triangle columns
for (col in triangle_columns) {
  # Convert the string values to numeric vectors
  result[[col]] <- lapply(result[[col]], convert_to_numeric_vector)
}

long_data <- result %>%
  pivot_longer(
    cols = starts_with("trial"),
    names_to = "trial_column",
    values_to = "responses"
  )

wide_data <- process(long_data)

write_csv(wide_data, here(params$preprocessing$output_file))
