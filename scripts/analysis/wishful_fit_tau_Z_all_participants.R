# This script fits tau (softmax temperature) and z (preference weighting) to maximize correlation 
# between individual participant responses and model predictions.

library(tidyverse)
library(ggplot2)
library(glue)
library(here)

source(here("scripts", "analysis", "model", "helpers.R"))

# Load data
participant_data <- read_csv(here("data", "derived", "preprocessed_participant_data.csv"))
model_data <- read_csv(here("data", "derived", "model_predictions_trials_used_4_Omegas.csv")) %>%
  rename(z = omega)

participant_names <- names(participant_data %>% select(starts_with("participant_")))
trial_indices <- 1:nrow(participant_data)

taus <- seq(0.01, 1, by = 0.01)
zs <- unique(model_data$z)
param_grid <- expand.grid(tau = taus, z = zs)

correlation_results <- tibble(participant = character(), tau = numeric(), z = numeric(), wishful_cor = numeric())

# Main grid search loop
for (i in seq_len(nrow(param_grid))) {
  model_z <- model_data %>% filter(z == param_grid$z[i])
  model_softmaxed <- softmax_both_models(model_z, param_grid$tau[i])

  combined_df <- participant_data %>%
    left_join(
      model_softmaxed %>% select(trial_number, utterance, Wishful_Softmaxed),
      by = c("trial_number", "utterance")
    )

  wishful_correlations <- calculate_correlations("Wishful_Softmaxed", participant_names, combined_df, trial_indices)

  new_results <- tibble(
    participant = participant_names,
    tau = param_grid$tau[i],
    z = param_grid$z[i],
    wishful_cor = wishful_correlations
  )

  correlation_results <- bind_rows(correlation_results, new_results)
}

# Extract best z/tau pair per participant
max_correlations_wishful <- correlation_results %>%
  group_by(participant) %>%
  filter(wishful_cor == max(wishful_cor)) %>%
  slice(1) %>%
  ungroup() %>%
  mutate(z = round(as.numeric(format(z, scientific = FALSE)), 2))

# Histogram of best z values
bin_width <- 0.1
min_z <- floor(min(max_correlations_wishful$z)) - bin_width
max_z <- ceiling(max(max_correlations_wishful$z)) + bin_width
bin_edges <- seq(min_z, max_z, by = bin_width) - (bin_width / 2)

hist_data <- hist(max_correlations_wishful$z, plot = FALSE, breaks = bin_edges)
max_y <- max(hist_data$counts)

hist_plot <- ggplot(max_correlations_wishful, aes(x = z)) +
  geom_histogram(breaks = bin_edges, fill = "grey", color = "black", alpha = 0.7) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
  scale_x_continuous(limits = c(-2, max_z)) +
  scale_y_continuous(limits = c(0, max_y)) +
  labs(title = "Histogram of Fitted Wishful Parameters", x = "Wishful z", y = "Frequency") +
  theme_minimal()
ggsave(here("figs", "fitting_ws", "histogram", "histogram7.pdf"), hist_plot, width = 6, height = 4)

# Colored histogram
bin_width <- 0.0995
bins <- seq(-2.0995, 4.0995, by = bin_width)

binned_data <- max_correlations_wishful %>%
  mutate(bin = cut(z, breaks = bins, include.lowest = TRUE, right = FALSE)) %>%
  group_by(bin) %>%
  summarise(count = n(), z = mean(z, na.rm = TRUE)) %>%
  complete(bin = factor(levels(bin)), fill = list(count = 0, z = 0)) %>%
  mutate(
    bin_lower = as.numeric(gsub("\\[|\\(|,.*", "", bin)),
    bin_upper = as.numeric(gsub(".*,|\\]", "", bin))
  )

histogram <- ggplot(binned_data, aes(x = bin, y = count, fill = z)) +
  geom_bar(stat = "identity", color = "black", alpha = 0.7) +
  scale_fill_gradient(low = "lightblue", high = "darkblue") +
  labs(title = "Fitted Wishful Parameters (Z)", x = "Z Bin", y = "Count") +
  scale_x_discrete(labels = round(binned_data$bin_lower, 2)) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 90, vjust = 0.5))
ggsave(here("figs", "fitting_ws", "histogram", "histogram5.pdf"), histogram, width = 8, height = 5)

# Statistical tests
t.test(max_correlations_wishful$z)
binom.test(sum(max_correlations_wishful$z > 0), nrow(max_correlations_wishful))

# Compare to standard model (z = 0)
correlation_results <- correlation_results %>% mutate(z = round(as.numeric(format(z, scientific = FALSE)), 1))
standard_model <- correlation_results %>% filter(z == 0) %>% rename(standard_cor = wishful_cor)

max_correlations_standard <- standard_model %>%
  group_by(participant) %>%
  filter(standard_cor == max(standard_cor)) %>%
  slice(1) %>%
  ungroup()

# Scatterplot of standard vs. wishful correlations
merged_cors <- inner_join(
  max_correlations_standard %>% select(participant, standard_cor),
  max_correlations_wishful %>% select(participant, z, wishful_cor),
  by = "participant"
)

scatterplot <- ggplot(merged_cors, aes(x = wishful_cor, y = standard_cor, color = z)) +
  geom_point(size = 3, alpha = 0.7) +
  geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "red") +
  scale_color_gradient(high = "darkblue", low = "lightblue") +
  xlim(c(-0.5, 1)) + ylim(c(-0.5, 1)) +
  theme_minimal() +
  labs(title = "Wishful vs Standard Correlation", x = "Wishful", y = "Standard") +
  theme(aspect.ratio = 1)
ggsave(here("figs", "fitting_ws", "scatterplot.pdf"), scatterplot, width = 4, height = 4)

# T-test for correlation difference
merged_cors <- merged_cors %>% mutate(diff = wishful_cor - standard_cor)
t.test(merged_cors$wishful_cor, merged_cors$standard_cor)
