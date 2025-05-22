import pandas as pd
import matplotlib.pyplot as plt
import mpltern
from PIL import Image
import numpy as np
import os
import shutil
import re
from matplotlib.colors import to_rgba
from pathlib import Path

ROOT_DIR = Path(__file__).resolve().parents[1]
FIGS_DIR = ROOT_DIR / "figs" / "ternary_plots"

# Load the data
file_path = "analysis/trial_data_for_ternary_fixed_tau.csv"  # Adjust as needed
df = pd.read_csv(file_path)

# Preprocess `Source` in `df` to extract the trial number
df['Source'] = df['Source'].apply(lambda x: int(re.search(r'\d+', x).group()))

old_csv_path = "analysis/combined_model_participants_Exp1_fixed_omega_strings_fixed_tau.csv"
old_data = pd.read_csv(old_csv_path)
old_data['trial_number'] = old_data['trial_number'].astype(int)

def extract_preferences_observations(trial_number):
    """
    Extract preferences and observations from the old CSV for the given trial.
    """
    # Ensure trial_number is an integer
    trial_number = int(trial_number)
    old_data['trial_number'] = old_data['trial_number'].astype(int)

    # Filter for the trial
    trial_data = old_data[old_data['trial_number'] == trial_number]
    
    if trial_data.empty:
        print(f"Warning: No data found for trial_number {trial_number} in old_data.")
        return [None, None, None], [None, None, None]

    # Extract preferences and observations
    preferences = [
        trial_data['Preference_A'].iloc[0],
        trial_data['Preference_B'].iloc[0],
        trial_data['Preference_C'].iloc[0],
    ]
    observations = [
        trial_data['Obs_A'].iloc[0],
        trial_data['Obs_B'].iloc[0],
        trial_data['Obs_C'].iloc[0],
    ]
    return preferences, observations

# Image directory (ensure these files are present)
image_dir = "stim_images"  # Replace with the actual path
images = {
    "Chemical A": os.path.join(image_dir, "chemical1_mini.png"),
    "Chemical B": os.path.join(image_dir, "chemical2_mini.png"),
    "Chemical C": os.path.join(image_dir, "chemical3_mini.png"),
}

def add_image(fig, img_path, x, y, zoom=0.1):
    """
    Add an image to the plot using figure-relative coordinates.
    """
    if os.path.exists(img_path):
        img = Image.open(img_path)
        img_array = np.array(img)  # Convert Pillow image to NumPy array
        fig.figimage(img_array, xo=x * fig.get_size_inches()[0] * fig.dpi, 
                     yo=y * fig.get_size_inches()[1] * fig.dpi, origin='upper', resize=zoom)
    else:
        print(f"Image not found: {img_path}")
def detect_overlaps(data, threshold=0.02):
    """
    Detect overlapping points in the ternary plot.
    
    Parameters:
        data (pd.DataFrame): DataFrame containing `Chemical A`, `Chemical B`, `Chemical C`.
        threshold (float): Distance threshold for considering points as overlapping.
        
    Returns:
        overlaps (list of tuples): List of indices of overlapping points.
    """
    overlaps = []
    coords = data[['Chemical A', 'Chemical B', 'Chemical C']].values
    for i, coord1 in enumerate(coords):
        for j, coord2 in enumerate(coords):
            if i >= j:  # Avoid duplicates and self-comparison
                continue
            distance = np.linalg.norm(coord1 - coord2)
            if distance < threshold:
                overlaps.append((i, j))
    return overlaps


def create_ternary_plot(trial_data, trial_number, preferences, observations, obs_symbol, output_dir):
    """
    Create a ternary plot for a single trial.
    """
    # Filter the data for participants and special points
    participants = trial_data[trial_data['Group'] == 'Participants']
    model_points = trial_data[(trial_data['Group'] == 'Standard') | (trial_data['Group'] == 'Wishful')]
    mean_points = trial_data[trial_data['Group'] == 'Mean Response']

    # Create ternary plot
    fig, ax = plt.subplots(subplot_kw={'projection': 'ternary'}, figsize=(18, 18))
    plt.subplots_adjust(left=0.15, right=0.85, top=0.85, bottom=0.15)


    # Plot special points (Standard, Wishful, Mean Response)
    
    # Define colors for groups
    colors = {
        "Standard": "#ff5656",  # Bright Blue
        "Wishful": "#5656ff",  # Bright Orange
        "Mean Response": "#56ff56",  # Bright Magenta
        "Participants": "#b3b3b3ff",  # Light Gray
        "Overlaps": '#aa56ff'
    }

            # Plot participants
    ax.scatter(
        participants['Chemical A'], participants['Chemical B'], participants['Chemical C'],
        color=colors["Participants"], s=participants['PointSize'] * 10, 
        alpha=0.5,
        edgecolor='black', linewidth=0.1, 
        label='Participants'
    )

    # Apply the detection function
    overlap_indices = detect_overlaps(model_points)

    # Extract overlapping values based on detected indices
    overlap_values = set()
    for i, j in overlap_indices:
        coord1 = tuple(model_points.iloc[i][['Chemical A', 'Chemical B', 'Chemical C']])
        coord2 = tuple(model_points.iloc[j][['Chemical A', 'Chemical B', 'Chemical C']])
        overlap_values.add(coord1)
        overlap_values.add(coord2)

    # Filter non-overlapping points
    non_overlapping_points = model_points[
        ~model_points.apply(
            lambda row: (row['Chemical A'], row['Chemical B'], row['Chemical C']) in overlap_values, axis=1
        )
    ]


    # Highlight overlaps on the plot
    for i, j in overlap_indices:
        coord1 = model_points.iloc[i]
        coord2 = model_points.iloc[j]
        ax.scatter(
            coord1['Chemical A'], coord1['Chemical B'], coord1['Chemical C'],
            color=colors['Overlaps'], alpha=0.5, edgecolor='black', linewidth=0.5, s=60, label='Overlap'
            )
        ax.scatter(
        coord2['Chemical A'], coord2['Chemical B'], coord2['Chemical C'],
        color=colors['Overlaps'], alpha=0.5, edgecolor='black', linewidth=0.5, s=60, label='Overlap'
            )
        
    for _, point in non_overlapping_points.iterrows():
        ax.scatter(
            point['Chemical A'], point['Chemical B'], point['Chemical C'],
            color=colors[point['Group']], alpha = 0.8, 
            edgecolor='black', linewidth=0.5, 
            s=point['PointSize'] * 15, label=point['Group']
        )
        
    for _, point in mean_points.iterrows():
        ax.scatter(point['Chemical A'], point['Chemical B'], point['Chemical C'],
            color=colors[point['Group']], alpha = 0.8, 
            edgecolor='black', linewidth=0.5, 
            s=point['PointSize'] * 15, label=point['Group'])


    # Add images at vertices
    add_image(fig, images["Chemical A"], x=0.405, y=0.85, zoom=0.0001)
    add_image(fig, images["Chemical B"], x=0.41, y=1.9, zoom=0.0001)
    add_image(fig, images["Chemical C"], x=7.65, y=1.9, zoom=0.0001)

    ax.grid(False)
    ax.tick_params(axis='both', which='both', length=0, labelsize=0, color="white", labelcolor="white")

     # Add preferences and observations as text (using specific pixel positions)
    # Define mappings for label positions based on preference values
    top_vertex_positions = {
        "HATE": {"x": 0.327, "y": 0.82},
        "DISLIKE": {"x": 0.32, "y": 0.82},
        "INDIFF": {"x": 0.33, "y": 0.82},
        "LIKE": {"x": 0.33, "y": 0.82},
        "LOVE": {"x": 0.325, "y": 0.82},
    }

    bottom_left_vertex_positions = {
        "HATE": {"x": 0.105, "y": 0.39},
        "DISLIKE": {"x": 0.115, "y": 0.39},
        "INDIFF": {"x": 0.11, "y": 0.39},
        "LIKE": {"x": 0.1, "y": 0.39},
        "LOVE": {"x": 0.105, "y": 0.39},
    }

    bottom_right_vertex_positions = {
        "HATE": {"x": 0.9, "y": 0.39},
        "DISLIKE": {"x": 0.885, "y": 0.39},
        "INDIFF": {"x": 0.9, "y": 0.39},
        "LIKE": {"x": 0.89, "y": 0.39},
        "LOVE": {"x": 0.90, "y": 0.39},
    }

    def get_label_position(pref, vertex):
        """
        Get the label position based on preference value and vertex.
        """
        if vertex == 0:  # Top vertex
            return top_vertex_positions.get(pref, {"x": 0.34, "y": 0.79})
        elif vertex == 1:  # Bottom-left vertex
            return bottom_left_vertex_positions.get(pref, {"x": 0.11, "y": 0.39})
        elif vertex == 2:  # Bottom-right vertex
            return bottom_right_vertex_positions.get(pref, {"x": 0.885, "y": 0.39})
        return {"x": 0.5, "y": 0.5}  # Default position (should not happen)

    default_font = plt.rcParams['font.family']
    plt.rcParams['font.family'] = default_font

    # Top vertex
    pos0 = get_label_position(preferences[0], 0)
    fig.text(pos0["x"], pos0["y"], f"{preferences[0]}", ha='center', fontsize=8)

    # Bottom-left vertex
    pos1 = get_label_position(preferences[1], 1)
    fig.text(pos1["x"], pos1["y"], f"{preferences[1]}", ha='center', fontsize=8)

    # Bottom-right vertex
    pos2 = get_label_position(preferences[2], 2)
    fig.text(pos2["x"], pos2["y"], f"{preferences[2]}", ha='center', fontsize=8)

# Define a dictionary to store observations and symbols
    observation_data = {}

# Loop through all utterances and prepare the data
    for i, observation in enumerate(observations):
        num_success = int(observation)
        num_failure = 5 - num_success

        # Prepare the checkmarks and crosses
        checkmarks = f"{'✓' * num_success}"  # Green checkmarks
        crosses = f"{' ' * num_success}{'✗' * num_failure}"  # Red crosses

        # Prepare the colored blocks
        green_blocks = f"{'■' * num_success}"  # Green blocks
        red_blocks = f"{' ' * num_success}{'■' * num_failure}"  # Red blocks

        # Store the data for this utterance
        observation_data[f"utterance_{i}"] = {
            "checkmarks": checkmarks,
            "crosses": crosses,
            "green_blocks": green_blocks,
            "red_blocks": red_blocks,
        }
    
    plt.rcParams['font.family'] = 'monospace'

    if obs_symbol == "checks":
        fig.text(0.23, 0.77, observation_data["utterance_0"]["checkmarks"], ha='left', fontsize=8, c='#99d67fff')
        fig.text(0.23, 0.77, observation_data["utterance_0"]["crosses"], ha='left', fontsize=8, c='#ff7272ff')

        fig.text(0.01, 0.34, observation_data["utterance_1"]["checkmarks"], ha='left', fontsize=8, c='#99d67fff')
        fig.text(0.01, 0.34, observation_data["utterance_1"]["crosses"], ha='left', fontsize=8, c='#ff7272ff')

        fig.text(0.81, 0.34, observation_data["utterance_2"]["checkmarks"], ha='left', fontsize=8, c='#99d67fff')
        fig.text(0.81, 0.34, observation_data["utterance_2"]["crosses"], ha='left', fontsize=8, c='#ff7272ff')
    elif obs_symbol == "boxs":
        fig.text(0.23, 0.77, observation_data["utterance_0"]["green_blocks"], ha='left', fontsize=8, c='#99d67fff')
        fig.text(0.23, 0.77, observation_data["utterance_0"]["red_blocks"], ha='left', fontsize=8, c='#ff7272ff')
        
        fig.text(0.01, 0.34, observation_data["utterance_1"]["green_blocks"], ha='left', fontsize=8, c='#99d67fff')
        fig.text(0.01, 0.34, observation_data["utterance_1"]["red_blocks"], ha='left', fontsize=8, c='#ff7272ff')
        
        fig.text(0.81, 0.34, observation_data["utterance_2"]["green_blocks"], ha='left', fontsize=8, c='#99d67fff')
        fig.text(0.81, 0.34, observation_data["utterance_2"]["red_blocks"], ha='left', fontsize=8, c='#ff7272ff')

    plt.rcParams['font.family'] = default_font

    # Save plot
    output_file = os.path.join(output_dir, f"{trial_number}_ternary_plot.pdf")
    plt.savefig(output_file, dpi=900)
    plt.close()

# Output directory for saving check plots
checks_dir = FIGS_DIR / "checks"
if checks_dir.exists():
    shutil.rmtree(checks_dir)
checks_dir.mkdir(parents=True, exist_ok=True)

#Output directory for saving box plots
box_dir = FIGS_DIR / "boxs"
if checks_dir.exists():
    shutil.rmtree(checks_dir)
checks_dir.mkdir(parents=True, exist_ok=True)

# Loop through each trial and create plots
trial_numbers = df['Source'].unique()
for trial_number in trial_numbers:
     trial_data = df[df['Source'] == trial_number]
     preferences, observations = extract_preferences_observations(trial_number)
     create_ternary_plot(trial_data, trial_number, preferences, observations, "checks", checks_dir)
     create_ternary_plot(trial_data, trial_number, preferences, observations, "boxs", box_dir)

