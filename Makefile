# Chemicals-main Makefile

# Directories
ROOT_DIR := $(shell pwd)
SCRIPTS := $(ROOT_DIR)/scripts
STIM_CREATION := $(SCRIPTS)/stim_creation
MODEL_CREATION := $(SCRIPTS)/model_creation
MODEL_ANALYSIS := $(SCRIPTS)/analysis/model
PARTICIPANT_ANALYSIS := $(SCRIPTS)/analysis/participants
ANALYSIS := $(SCRIPTS)/analysis
DERIVED := $(ROOT_DIR)/data/derived

#Ensure R environment is ready
.PHONY: install_r_packages
install_r_packages:
	Rscript -e "if (!requireNamespace('renv', quietly = TRUE)) install.packages('renv'); renv::restore()"

#Sample Trials
.PHONY: sample_trials
sample_trials: install_r_packages
	Rscript $(STIM_CREATION)/sample_trials_norepeats.R

#Generate Non-Trial Stimuli and Pretty Tables
.PHONY: stim
stim: sample_trials
	python3 $(STIM_CREATION)/gen_nontrial_stim.py
	python3 $(STIM_CREATION)/pretty_tables.py

#Run Model Predictions
.PHONY: run_models
run_models:
	python3 $(MODEL_CREATION)/run_model_many_Zs.py  # or use brute_force_no_softmax.py

#Preprocess Model Predictions
.PHONY: preprocess_model
preprocess_model: install_r_packages
	Rscript $(MODEL_ANALYSIS)/preprocess_model_predictions.R
	Rscript $(MODEL_ANALYSIS)/preprocess_model_predictions_varying_Z.R

#Note the workflow here is no longer required as part of the preprocessing is the anonymizing of the data
# Preprocess Participant Data
#.PHONY: preprocess_participants
#preprocess_participants: install_r_packages
#	#Rscript $(PARTICIPANT_ANALYSIS)/preprocess_participant_data.R

# Fit Tau (Fixed or Group Mean)
.PHONY: fit_tau
fit_tau: install_r_packages
	Rscript $(MODEL_ANALYSIS)/fix_tau.R
	Rscript $(MODEL_ANALYSIS)/tau_fit.R
	

# Analyze Participants at Group Level
.PHONY: analyze_group
analyze_group: install_r_packages
	Rscript $(PARTICIPANT_ANALYSIS)/analyze_participants.R

# Fit Z and Tau to Participant Data
.PHONY: fit_wishful_parameter
fit_wishful_parameter: install_r_packages
	Rscript $(ANALYSIS)/wishful_fit_tau_Z.R
	Rscript $(ANALYSIS)/wishful_fit_tau_Z_all_participants.R

# Create Ternary Plots
.PHONY: ternary_plots
ternary_plots: install_r_packages
	Rscript $(ANALYSIS)/ternary_plots_preprocess.R
	python3 $(SCRIPTS)/ternary_plots.py

# Full Pipeline
.PHONY: all
all: stim run_models preprocess_model fit_tau analyze_group fit_z_tau_individual fit_z_tau_group ternary_plots

# Clean generated figures and derived data
.PHONY: clean
clean:
	rm -rf figs/* ternary_plots_checks/ ternary_plots_boxs/ $(DERIVED)/*.csv
