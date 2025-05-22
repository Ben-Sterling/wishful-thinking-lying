library(tidyverse)
library(here)
library(yaml)

# Load parameters from YAML
params <- yaml::read_yaml(here("params.yaml"))

ev_path <- here(params$brute_force$output_file)   # Path to raw model output
out_dir <- here("data", "derived") 

## ------------------------------------------------------------------------- ##
## 1.  Load & tidy the full EV grid ---------------------------------------- ##

raw <- read_csv(ev_path, col_names = FALSE, show_col_types = FALSE)
raw_pref_range <- as.vector(raw[1, ])
values <- as.numeric(raw_pref_range[2:6])
names(values) <- c("HATES", "DISLIKES", "IS INDIFFERENT TO", "LIKES", "LOVES")
pref_range <- as.data.frame(as.list(values))

data <- read_csv(ev_path, skip = 1, show_col_types = FALSE)

data[] <- lapply(data, as.numeric)

set.seed(123)
bins <- params$sampling$bins
n_per_bin <- params$sampling$n_per_bin
bin_breaks <- seq(0, 1, length.out = bins + 1)
tau <- params$sampling$tau


##########################################################################################

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
data <- data %>% mutate(
  Preference_A_alt = Preference_A * transformation_factors$multiplier + transformation_factors$addition,
  Preference_B_alt = Preference_B * transformation_factors$multiplier + transformation_factors$addition,
  Preference_C_alt = Preference_C * transformation_factors$multiplier + transformation_factors$addition,
  obs_pref_idA = as.numeric(paste0(Obs_A, Preference_A_alt)),
  obs_pref_idB = as.numeric(paste0(Obs_B, Preference_B_alt)),
  obs_pref_idC = as.numeric(paste0(Obs_C, Preference_C_alt))
) 

#Sort the pref - obs pairs and create a unique pref-obs pairs id for each unique set of three pairs
data <- data %>% rowwise() %>%
  mutate(
    obs_pref_id = paste(max(c(obs_pref_idA, obs_pref_idB, obs_pref_idC)), 
                        median(c(obs_pref_idA, obs_pref_idB, obs_pref_idC)), 
                        min(c(obs_pref_idA, obs_pref_idB, obs_pref_idC)))
  )

#There 5*6=30 possible pairings of evidence and preference for a single chemical
#There's 30 choose 3 with replacement ways to order those pairings for 3 chemicals
#We expect 4960 distinct ids for 4960 unique pref-obs pair sets
n_distinct(data$obs_pref_id)

data <- data %>%
  group_by(obs_pref_id) %>%
  mutate(config_group = cur_group_id()) %>%
  ungroup()


data %>%
  group_by(obs_pref_id) %>%
  summarize(
    min_standard = min(Standard),
    max_standard = max(Standard),
    min_wishful = min(Wishful),
    max_wishful = max(Wishful)
  )

##########################################################################################
tau <- 0.1

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

data <- data %>%
  mutate(block = (row_number() - 1) %/% 3 + 1)

data <- data %>%
  group_by(block) %>%
  mutate(
    # Check conditions at the group level
    apply_softmax = if (n() == 3 && 
                        all(obs_pref_id == first(obs_pref_id)) && 
                        all(utterance == c(0, 1, 2))) TRUE else FALSE
  ) %>%
  # Apply softmax consistently across the group
  mutate(
    Standard = if (first(apply_softmax)) multinomial_softmax(Standard, tau) else rep(NA, n()),
    Wishful = if (first(apply_softmax)) multinomial_softmax(Wishful, tau) else rep(NA, n())
  ) %>%
  ungroup()

data <- data %>%
  mutate(Difference = abs(Wishful - Standard))

################################################################################
#Add columns for binning the range of Standard and Wishful Model Outputs
data <- data %>%
  mutate(
    Standard_bin = cut(Standard, breaks = bin_breaks, labels = seq_len(bins), include.lowest = TRUE),
    Wishful_bin = cut(Wishful, breaks = bin_breaks, labels = seq_len(bins), include.lowest = TRUE)
  )


################################################################################
# Buckets 1 and 2: Sampling Unique Configurations by Bin
# 
# 1. **Purpose**:
#    - The goal is to sample a fixed number (`n_per_bin`) of functionally unique
#      configurations from each bin in a specified column (e.g., "Standard_bin" or "Wishful_bin").
#
# 2. **Key Steps**:
#    - **Filter by Bin**: For each unique bin in the specified column, filter the data
#      to include only rows corresponding to that bin.
#    - **Ensure Uniqueness**: Use `distinct(config_group, .keep_all = TRUE)` to ensure that
#      only one row is retained per unique configuration group within each bin.
#    - **Sample Configurations**: Randomly sample `n_per_bin` configurations from the filtered
#      rows for each bin. Sampling is performed without replacement (`replace = FALSE`).
#
# 3. **Implementation**:
#    - The helper function `sample_bins` takes three arguments:
#        - `data`: The dataset from which to sample.
#        - `bin_column`: The name of the column defining the bins (e.g., "Standard_bin").
#        - `n_per_bin`: The number of configurations to sample per bin.
#    - The sampled configurations for each bin are stored in a list, which is
#      combined into a single dataset using `bind_rows()`.
#
# 4. **Application**:
#    - `sampled_standard_configs`: Contains sampled configurations for the "Standard_bin".
#    - `sampled_wishful_configs`: Contains sampled configurations for the "Wishful_bin".
#
# This process is essential for selecting representative configurations from the
# range of predictions made by the Standard and Wishful models while ensuring
# sufficient diversity across bins.
################################################################################


sample_bins <- function(data, bin_column, n_per_bin) {
  sampled_configurations_list <- list()
  
  for (bin in unique(data[[bin_column]])) {
    bin_data <- data %>%
      filter(!!sym(bin_column) == bin) %>%
      distinct(config_group, .keep_all = TRUE)  # Retain one row per unique config per bin
    
    sampled_bin <- bin_data %>%
      slice_sample(n = n_per_bin, replace = FALSE)  # Sample configs
    
    sampled_configurations_list[[bin]] <- sampled_bin
  }
  
  bind_rows(sampled_configurations_list)
}

# Sample Standard and Wishful Configurations
sampled_standard_configs <- sample_bins(data, "Standard_bin", n_per_bin)
sampled_wishful_configs <- sample_bins(data, "Wishful_bin", n_per_bin)

print("Standard Config Counts by Bin")
sampled_standard_configs %>% 
  group_by(Standard_bin) %>%
  summarise(n = n_distinct(obs_pref_id)) %>%
  print()

print("Wishful Config Counts by Bin")
sampled_wishful_configs %>%
  group_by(Wishful_bin) %>%
  summarise(n = n_distinct(obs_pref_id)) %>%
  print()

sampled_standard_configs %>%
  arrange(Standard_bin, obs_pref_id) %>%
  print(n = 20)

################################################################################
# Bucket 3: Selecting Top Unique Configurations
#
# 1. **Purpose**:
#    - The aim is to identify the configurations with the highest `Difference` values,
#      ensuring that no duplicate configurations (based on `obs_pref_id`) are included.
#    - These top configurations are later used to analyze the most extreme cases where
#      the models diverge significantly in their predictions.
#
# 2. **Key Steps**:
#    - **Sort by `Difference`**: Arrange the data in descending order based on the
#      `Difference` column to prioritize the configurations with the largest differences.
#    - **Ensure Uniqueness**: Use `distinct(obs_pref_id, .keep_all = TRUE)` to retain
#      only the first occurrence of each unique configuration (identified by `obs_pref_id`).
#    - **Select Top Configurations**: Use `slice(1:10)` to extract the top 10 rows after
#      sorting and deduplication.
#
# 3. **Output**:
#    - `top_unique_configs`: A dataset containing the top 10 functionally unique
#      configurations with the highest `Difference` values.
#
# This step is critical for highlighting the most informative configurations where
# the models differ the most, providing valuable insights for further analysis.
################################################################################

top_unique_configs <- data %>%
  arrange(desc(Difference)) %>%
  distinct(obs_pref_id, .keep_all = TRUE) %>%
  slice(1:10)

################################################################################

sampled_configs <- rbind(sampled_standard_configs, sampled_wishful_configs, top_unique_configs)

################################################################################
# Aggregating Sampled Rows Across Buckets
#
# **Purpose**:
# - The aim is to consolidate configurations and ensure the inclusion of the corresponding
#   rows for all utterance values (0, 1, 2) while maintaining functional uniqueness.
#
# **Steps**:
# 1. **Define Helper Function `retrieve_sampled_rows`**:
#    - This function retrieves rows from `data` that correspond to the configurations
#      in `sampled_configs` (identified by `obs_pref_id`).
#    - Key operations:
#      - **Join Data**: Use `semi_join` to match rows in `data` to the sampled configurations
#        based on `obs_pref_id`.
#      - **Filter by Utterance**: Retain only rows with utterance values 0, 1, and 2.
#      - **Ensure Distinctness**: Deduplicate rows based on `obs_pref_id` and `utterance`.
#      - **Ungroup**: Remove grouping to prepare for combining datasets.
#
# 2. **Retrieve Rows for Each Bucket**:
#    - **Standard Configurations**: Call `retrieve_sampled_rows` for `sampled_standard_configs`.
#    - **Wishful Configurations**: Call `retrieve_sampled_rows` for `sampled_wishful_configs`.
#    - **Top Unique Configurations**: Call `retrieve_sampled_rows` for `top_unique_configs`.
#
# 3. **Validation**:
#    - Group by `obs_pref_id` and count rows to ensure all three utterances are present for
#      each configuration.
#    - Use `print` statements to provide debug information for each bucket.
#
# 4. **Combine Sampled Rows**:
#    - Use `bind_rows` to aggregate all rows across the three buckets into a unified dataset
#      (`sampled_data`), which will serve as the final output for further analysis.
#
# This process ensures comprehensive coverage of configurations across all buckets,
# retaining the most informative configurations and their respective utterances.
################################################################################



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


sampled_standard <- retrieve_sampled_rows(data, sampled_standard_configs)
sampled_wishful <- retrieve_sampled_rows(data, sampled_wishful_configs)
sampled_top_unique <- retrieve_sampled_rows(data, top_unique_configs)

print("Sampled Standard Rows")
sampled_standard %>% group_by(obs_pref_id) %>% summarise(row_count = n()) %>% print()

print("Sampled Wishful Rows")
sampled_wishful %>% group_by(obs_pref_id) %>% summarise(row_count = n()) %>% print()

print("Sampled Top Unique")
sampled_top_unique %>% group_by(obs_pref_id) %>% summarise(row_count = n()) %>% print()
all(top_unique_configs$obs_pref_id %in% data$obs_pref_id)

sampled_data <- retrieve_sampled_rows(data, sampled_configs)

#sampled_data <- bind_rows(sampled_standard, sampled_wishful, sampled_top_unique)

# Ensure `sampled_data` is sorted based on the order of `obs_pref_id` and `config_group` in sampled_configs
sampled_data <- sampled_data %>%
  arrange(
    factor(obs_pref_id, levels = sampled_configs$obs_pref_id),
    factor(config_group, levels = sampled_configs$config_group)
  )

######################################################################################
#Normalization Step

normalize <- function(values) {
  values / sum(values)
}

tau <- 0.1

log_softmax <- function(values, tau){
  max_ev <- max(values)
  (1/tau) * values - (1/tau) * max_ev
}

multinomial_softmax <- function(values){
  exp(log_softmax(values, tau))
}

sampled_data <- sampled_data %>%
  group_by(obs_pref_id) %>%
  mutate(
    wishful_normalized = normalize(Wishful), 
    standard_normalized = normalize(Standard),
    wishful_softmaxed = multinomial_softmax(Wishful),
    standard_softmaxed = multinomial_softmax(Standard)
  ) %>%
  ungroup()

# Define the desired column order
desired_order <- c(
  "trial_number", "utterance", "Standard", "Wishful", "mean_response", 
  "Preference_A", "Preference_B", "Preference_C", "Obs_A", "Obs_B", "Obs_C"
)



######################################################################################

validation <- sampled_data %>%
  group_by(obs_pref_id) %>%
  summarise(row_count = n()) %>%
  filter(row_count != 3)
print("Validation: Rows with Missing Utterances")
print(validation)

# Check Bin Distributions
print("Sampled Standard Bin Distribution")
print(table(sampled_standard$Standard_bin))

print("Sampled Wishful Bin Distribution")
print(table(sampled_wishful$Wishful_bin))

print("Total Sampled Data Rows")
expected_rows <- (bins * n_per_bin * 3 * 2) + (10 * 3)
actual_rows <- nrow(sampled_data)
print(paste("Expected Rows:", expected_rows))
print(paste("Actual Rows:", actual_rows))

# Calculate the correlation and confidence interval
cor_test <- cor.test(sampled_data$Standard, sampled_data$Wishful)
correlation_full <- cor_test$estimate
conf_interval <- cor_test$conf.int

# Calculate total number of points
total_points <- nrow(sampled_data)
# Add a new column to categorize the rows
sampled_data <- sampled_data %>%
  mutate(
    bucket = case_when(
      row_number() <= 30 ~ "Standard Bucket (Red)",  # First 30 rows
      row_number() > 30 & row_number() <= 60 ~ "Wishful Bucket (Blue)",  # Second 30 rows
      row_number() > 60 ~ "Differences Bucket (Green)"  # Last 30 rows
    )
  )

# Calculate the correlation and confidence interval
cor_test <- cor.test(sampled_data$Standard, sampled_data$Wishful)
correlation_full <- cor_test$estimate
conf_interval <- cor_test$conf.int

# Calculate total number of points
total_points <- nrow(sampled_data)

# Create the plot
ggplot(sampled_data, aes(x = Standard, y = Wishful, color = bucket)) +
  geom_jitter(size = 3, width = 0.1, height = 0.1) +  # Add jitter to points
  scale_color_manual(values = c(
    "Standard Bucket (Red)" = "red", 
    "Wishful Bucket (Blue)" = "blue", 
    "Differences Bucket (Green)" = "green"
  )) +        
  labs(
    x = "Standard", 
    y = "Wishful", 
    title = "Standard vs Wishful",
    color = "Bucket"
  ) +
  theme_minimal() + 
  # Annotate with the correlation, confidence interval, and total points
  annotate("text", x = Inf, y = Inf, 
           label = paste0("Correlation: ", round(correlation_full, 2), 
                          "\n95% CI: [", round(conf_interval[1], 2), ", ", round(conf_interval[2], 2), "]"),
           hjust = 1.1, vjust = 2, size = 5, color = "black") +
  annotate("text", x = Inf, y = -Inf, label = paste("Total Points:", total_points),
           hjust = 1.1, vjust = -1, size = 5, color = "black")

# Create the plot
ggplot(sampled_data, aes(x = Standard, y = Wishful, color = as.factor(utterance))) +
  geom_jitter(size = 3, width = 0.1, height = 0.1) +  # Add jitter to points
  scale_color_manual(values = c("red", "blue", "green"),  
                     name = "Utterance",                 
                     labels = c("A", "B", "C")) +        
  labs(x = "Standard", y = "Wishful", title = "Standard vs Wishful") +
  theme_minimal() + 
  # Annotate with the correlation, confidence interval, and total points
  annotate("text", x = Inf, y = Inf, 
           label = paste0("Correlation: ", round(correlation_full, 2), 
                          "\n95% CI: [", round(conf_interval[1], 2), ", ", round(conf_interval[2], 2), "]"),
           hjust = 1.1, vjust = 2, size = 5, color = "black") +
  annotate("text", x = Inf, y = -Inf, label = paste("Total Points:", total_points),
           hjust = 1.1, vjust = -1, size = 5, color = "black")

sampled_chem_a <- sampled_data %>% filter(utterance == 0)

correlation_a <- cor(sampled_chem_a$Standard, sampled_chem_a$Wishful, method = "pearson")
ggplot(sampled_chem_a, aes(x = Standard, y = Wishful, color = "red")) +
  geom_point(size = 3) +  
  scale_color_manual(values = c("red"),  
                     name = "Utterance",                 
                     labels = c("A")) +        
  labs(x = "Standard", y = "Wishful", title = "Standard vs Wishful for Chem A") +
  theme_minimal() + 
  annotate("text", x = Inf, y = Inf, label = paste("Correlation:", round(correlation_a, 2)),
           hjust = 1.1, vjust = 1.5, size = 5, color = "black")

hist(sampled_data$Difference)
hist(sampled_data$Standard)
hist(sampled_data$Wishful)

################################################################################

View(sampled_configs)

# Output sampled data
write_csv(sampled_configs,
          file = here(out_dir, "final_samples_v5.csv"))

write_csv(sampled_data,
          file = here(out_dir, "sampled_data_test.csv"))