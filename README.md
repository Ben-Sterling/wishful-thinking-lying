# Chemicals Project: Modeling Wishful Thinking in Lying

This repository contains the full experimental and analytical pipeline supporting the study **"People Use Theory of Mind to Craft Lies Exploiting Audience Desires"** (Berke, Sterling, Chandra & Jara-Ettinger 2025, Cognitive Science Society). The project investigates how individuals strategically tailor lies based on what they believe others want to hear, incorporating a Bayesian cognitive model that accounts for wishful thinking in inference and deception.

## Project Overview

This codebase implements a modular pipeline from experimental stimulus generation through to model fitting, participant analysis, and visualization. It was designed to support the development and testing of a Rational Speech Act-style model that varies agents’ wishfulness (Z) and noise (τ) in predicting both model-generated and human-generated responses across a factorial stimulus space.

The pipeline is primarily written in **R** and **Python**, with task orchestration via a `Makefile`. The architecture is structured to ensure transparency, reproducibility, and modular testing of each component.

## Directory Structure

```text
Chemicals-main/
├── data/derived/              # Output directory for preprocessed data and model predictions
├── scripts/
│   ├── stim_creation/         # R & Python scripts for generating stimuli
│   ├── model_creation/        # Python scripts for generating model predictions
│   └── analysis/
│       ├── model/             # R scripts for fitting and evaluating models
│       └── participants/      # R scripts for participant-level data analysis
├── Makefile                   # Main task orchestrator for running the pipeline
```

## Pipeline Steps

The following stages are available via the `Makefile`. Each can be run independently to support iterative development and debugging. Full automation is also available via `make all`, though this is computationally intensive.

| Step                       | Description                                                                 |
|----------------------------|-----------------------------------------------------------------------------|
| \`make sample_trials\`       | Samples experimental trials without repetition using R                     |
| \`make stim\`                | Generates non-trial stimuli and formats pretty tables                      |
| \`make run_models\`          | Generates model predictions over Z-space (brute force or softmax-free)     |
| \`make preprocess_model\`    | Preprocesses and anonymizes model output                                  |
| \`make fit_tau\`             | Fits a fixed τ or group-mean τ to model predictions                        |
| \`make analyze_group\`       | Analyzes participant data at group level                                   |
| \`make fit_wishful_parameter\` | Fits Z and τ parameters to participant data individually and collectively |
| \`make ternary_plots\`       | Prepares and renders ternary plots for visualizing belief space alignment  |
| \`make clean\`               | Clears generated figures and derived data                                  |

## Performance Note

Running \`make all\` or \`make run_models\` is **not recommended** on local machines due to the computational load of the brute force model sweep and downstream inference. Instead, step through the pipeline using the individual \`make\` targets listed above to debug and validate components incrementally.

## 🔧 Dependencies

- **R** (with \`renv\` package manager)
- **Python 3** (tested with 3.9+)
- R packages and Python dependencies are specified implicitly via script-level declarations or renv.
- Requires \`make\`, a Unix-like shell, and a moderately powerful system to run full-scale analyses.
