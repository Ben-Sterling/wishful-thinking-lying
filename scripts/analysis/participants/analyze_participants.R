# Load necessary library
library(tidyverse)
library(ggplot2)
library(here)
#library(patchwork)
#library(gridExtra)
#library(grid)

#This script is for comparing models to average participant data.
# Load processed participant data
participant_data <- read_csv(here("data", "derived", "preprocessed_participant_data.csv"))
participant_names <- names(participant_data %>% select(starts_with("participant_")))

# Load model predictions
model_predictions <- read_csv(here("data", "derived", "models_with_fitted_taus_Exp1_fixed_omega.csv"))
model_predictions <- model_predictions %>%
  rename(Standard = Standard_Fitted_Softmaxed, Wishful = Wishful_Fitted_Softmaxed)

#combine data frames
combined_df <- participant_data %>%
  left_join(
    model_predictions %>%
      select(trial_number, utterance, Standard, Wishful, Preference_A, Preference_B, Preference_C, Obs_A, Obs_B, Obs_C, Control),
    by = c("trial_number", "utterance")
  )

#write_csv(combined_df %>% select(-X), "combined_model_participants_Exp1_fixed_omega_fixed_tau.csv")

#Try dropping the two control trials.
#combined_df <- combined_df %>% filter(Control == FALSE)

cor_test_standard <- cor.test(combined_df$Standard, combined_df$mean_response)
correlation_full_standard <- cor_test_standard$estimate
conf_interval_standard <- cor_test_standard$conf.int

cor_test_wishful <- cor.test(combined_df$Wishful, combined_df$mean_response)
correlation_full_wishful <- cor_test_wishful$estimate
conf_interval_wishful <- cor_test_wishful$conf.int

#########################################################################
#Scatterplots

# Define your hex code colors
hex_colors <- c("#ff99c8", "#f0d24c", "#b3ebf2")  # Replace with your desired hex codes
#"#fcf6db" was original color for chemical B but looked bad on white background
mean_v_standard <- ggplot(combined_df, aes(x = Standard, y = mean_response, color=as.factor(utterance))) +
  geom_point(size = 3, alpha=0.7) +
  geom_smooth(aes(x = Standard, y = mean_response), method = "lm", se = TRUE, color = "black") + # adds one overall best-fit line with CI
  labs(
    title = "Average Participant Response vs Standard Model",
    x = "Standard",
    y = "Mean Response",
    caption = paste0(
      "Correlation: ", round(correlation_full_standard, 2), 
      "\n95% CI: [", round(conf_interval_standard[1], 2), ", ", round(conf_interval_standard[2], 2), "]"
    )
  ) + xlim(c(0,1)) + ylim(c(0,1)) +
  theme_minimal() + theme(aspect.ratio = 1) +
  theme(
    plot.caption = element_text(hjust = 0, vjust = 1, size = 10)  # Adjust the caption's position and size
  ) + scale_color_manual(values = hex_colors)
mean_v_standard
ggsave("figs/scatterplots/standard.pdf", mean_v_standard, width = 6, height = 6, units = "in", dpi = 300)

mean_v_wishful <- ggplot(combined_df, aes(x = Wishful, y = mean_response, color=as.factor(utterance))) +
  geom_point(size = 3, alpha=0.7) +
  geom_smooth(aes(x = Wishful, y = mean_response), method = "lm", se = TRUE, color = "black") + # adds one overall best-fit line with CI
  labs(
    title = "Average Participant Response vs Wishful Model",
    x = "Wishful",
    y = "Mean Response",
    caption = paste0(
      "Correlation: ", round(correlation_full_wishful, 2), 
      "\n95% CI: [", round(conf_interval_wishful[1], 2), ", ", round(conf_interval_wishful[2], 2), "]"
    )
  ) + xlim(c(0,1)) + ylim(c(0,1)) +
  theme_minimal() + theme(aspect.ratio = 1) +
  theme(
    plot.caption = element_text(hjust = 0, vjust = 1, size = 10)  # Adjust the caption's position and size
  ) + scale_color_manual(values = hex_colors)
mean_v_wishful
ggsave("figs/scatterplots/wishful.pdf", mean_v_wishful, width = 6, height = 6, units = "in", dpi = 300)

#########################################################################

combined_df %>% 
  filter(abs(Wishful - 0.33) < 0.01) %>% 
  pull(trial_number)
#4  4  4 17 23 23 23 24 24 24 25 25 25 26 26 26 27 27 27

combined_df %>% 
  filter(abs(Wishful - 0.46) < 0.01) %>% 
  pull(trial_number)
#3 12 22 28 28 29 29 30 30 31 31


combined_df %>% 
  filter(abs(Wishful - 0.49) < 0.01) %>% 
  pull(trial_number)
#6  6 11 11 21 32 32

#########################################################################
#Bootstrap over utterances (points on the scatterplot) to get CI on difference in correlation between Standard and Wishful models.
#Note: This is kind of double-counting since 3 utterances but really 2 degrees of freedom

library(boot)
#compute the difference in correlation between the Wishful model and human, and the Standard model and human
compute_diff_cor <- function(data, indices){
  SampledData = data[indices,]
  r1 <- cor(SampledData$Wishful, SampledData$mean_response)
  r2 <- cor(SampledData$Standard, SampledData$mean_response)
  return(r1 - r2)
}

set.seed(1)
sims = boot(combined_df, compute_diff_cor, R = 10000)
boot.ci(sims)
sims$t0 #gives the mean.

#To deal with degrees of freedom issue, remove one of the utterances entirely (like Chemical A?). Shouldn't matter much.
reduced_combined_df <- combined_df %>% filter(utterance==0)

set.seed(1)
sims = boot(reduced_combined_df, compute_diff_cor, R = 10000)
boot.ci(sims) #only slightly reduce lower CI bound.
sims$t0 #gives the mean.

#Could also boostrap over trials, but that would be harder, and is that really the right thing to do when we are getting a lot of data from each trial? Not necessarily.

#########################################################################
#Individual participant-level correlations to main model
participant_names <- names(participant_data %>% select(starts_with("participant_")))
n = length(participant_names)

individual_correlations <- data.frame(
  participant = character(n),
  cor_standard = numeric(n),
  cor_standard_lower = numeric(n),
  cor_standard_upper = numeric(n),
  cor_wishful = numeric(n),
  cor_wishful_lower = numeric(n),
  cor_wishful_upper = numeric(n)
)

for(i in 1:n){
  participant <- participant_names[i]
  individual_correlations$participant[i] <- participant
  cor_test_standard <- cor.test(combined_df$Standard, combined_df[[participant]])
  individual_correlations$cor_standard[i] <- cor_test_standard$estimate
  individual_correlations$cor_standard_lower[i] <- cor_test_standard$conf.int[1]
  individual_correlations$cor_standard_upper[i] <- cor_test_standard$conf.int[2]
  cor_test_wishful <- cor.test(combined_df$Wishful, combined_df[[participant]])
  individual_correlations$cor_wishful[i] <- cor_test_wishful$estimate
  individual_correlations$cor_wishful_lower[i] <- cor_test_wishful$conf.int[1]
  individual_correlations$cor_wishful_upper[i] <- cor_test_wishful$conf.int[2]
}

individual_correlations <- individual_correlations %>% mutate(diff = cor_wishful - cor_standard)
View(individual_correlations %>% select(diff, cor_wishful, cor_standard))
individual_correlations %>% select(diff, cor_wishful, cor_standard) %>% summarise(mean(diff), mean(cor_wishful), mean(cor_standard))
t.test(individual_correlations$cor_wishful, individual_correlations$cor_standard)
#Not coming out great. In the right direction, but not significant.

# How does it look?
# Reorder participants by the magnitude of the differences
individual_correlations <- individual_correlations %>%
  mutate(participant = fct_reorder(participant, diff))
# Create the barplot showing only the differences
ggplot(individual_correlations, aes(x = participant, y = diff)) +
  geom_bar(stat = "identity", fill = "blue", alpha = 0.7) +
  coord_flip() +
  labs(title = "Delta in Correlation for Wishful and Standard ",
       x = "Participant",
       y = "Difference in Correlation") +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 90, hjust = 1))
#Not good.
