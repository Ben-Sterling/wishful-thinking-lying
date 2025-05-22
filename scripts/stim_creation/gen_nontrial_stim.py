import pandas as pd
import os
import random
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import yaml
import sys

ROOT_DIR = Path(__file__).resolve().parents[2]
sys.path.append(str(ROOT_DIR / "scripts" / "model_creation"))



from brute_force import define_pref_range

OUTPUT = ROOT_DIR / "figs"

with open(ROOT_DIR / "params.yaml", "r") as f:
    config = yaml.safe_load(f)

print("Loading config from:", ROOT_DIR / "params.yaml")


n = config["brute_force"]["n"]
z = config["brute_force"]["z"]
num_prefs = config["brute_force"]["num_prefs"]
pref_range = define_pref_range(z, num_prefs)

IMG_DIR = ROOT_DIR / "resources" / "images"
FONT_DIR = ROOT_DIR / "resources" / "fonts"

#Attn question 1: All preferences indifferent, A with 5/5, B and C with 0/5
#Attn question 2: All preferences indifferent, A and B and C with 1/5
attention_data = {
        "Preference_A": [0, 0, 0, 0],  #first 4 elem correspond to training info, last two to attention questions
        "Preference_B": [0, 0, 0, 0],  
        "Preference_C": [0, 0, 0, 0],  
        "Obs_A": [5, 0, 0, 0],         
        "Obs_B": [0, 5, 0, 0],         
        "Obs_C": [0, 0, 0, 5]         
    }
attention = pd.DataFrame(attention_data)

practice_data = {
    "Preference_A": [1, 0.5, 0, -0.5],  #first 4 elem correspond to training info, last two to attention questions
    "Preference_B": [0.5, 1, -0.5, 0],  
    "Preference_C": [0, -0.5, 1, 0.5],  
    "Obs_A": [5, 3, 0, 1],         
    "Obs_B": [0, 5, 1, 0],         
    "Obs_C": [1, 0, 5, 4],         
    }
practice = pd.DataFrame(practice_data)

control_data = {
    "Preference_A": [0, 0],  #first 4 elem correspond to training info, last two to attention questions
    "Preference_B": [0, 0],  
    "Preference_C": [0, 0],  
    "Obs_A": [5, 1],         
    "Obs_B": [3, 0],         
    "Obs_C": [4, 2],         
    }

control = pd.DataFrame(control_data)

def create_practice_tables(dataframe, dataframe_name, output_dir):
    # Load images
    success_image = Image.open(IMG_DIR / "trial_success.png")
    failure_image = Image.open(IMG_DIR / "trial_failure.png")
    chemical_images = {
        "A": Image.open(IMG_DIR / "chemical1.png"),
        "B": Image.open(IMG_DIR / "chemical2.png"),
        "C": Image.open(IMG_DIR / "chemical3.png")
    }
    chemical_horizontal_images = {
        "A": Image.open(IMG_DIR / "chemical1_horizontal.png"),
        "B": Image.open(IMG_DIR / "chemical2_horizontal.png"),
        "C": Image.open(IMG_DIR / "chemical3_horizontal.png")
    }

    # Resize chemical images to match the size of success/failure images
    qualtrics_white = (255, 255, 255, 255)  # White background color in Qualtrics
    for key in chemical_images:
        chemical_images[key] = chemical_images[key].resize(success_image.size)

        # Fill background with Qualtrics white
        filled_image = Image.new("RGBA", success_image.size, qualtrics_white)
        filled_image.paste(chemical_images[key], (0, 0), mask=chemical_images[key])
        chemical_images[key] = filled_image

    # Resize horizontal icons to match text height and add white background
    font_path = FONT_DIR / "arial.ttf"
    font_size = 50
    header_font_size = 80
    try:
        font = ImageFont.truetype(str(font_path), font_size)
        header_font = ImageFont.truetype(str(font_path), header_font_size)
    except:
        print("Warning: Custom font not found, falling back to default font.")
        font = ImageFont.load_default()
        header_font = font

    text_bbox = header_font.getbbox("Sample Text")
    text_height = text_bbox[3] - text_bbox[1]
    for key in chemical_horizontal_images:
        aspect_ratio = chemical_horizontal_images[key].width / chemical_horizontal_images[key].height
        new_width = int(aspect_ratio * text_height)
        resized_icon = chemical_horizontal_images[key].resize((new_width, text_height))

        # Add white background
        filled_icon = Image.new("RGBA", resized_icon.size, qualtrics_white)
        filled_icon.paste(resized_icon, (0, 0), mask=resized_icon)
        chemical_horizontal_images[key] = filled_icon

    # Constants for table layout
    cell_width, cell_height = success_image.size
    table_width = cell_width * 6 + cell_width  # Extra column for chemical image
    table_height = cell_height * 3

    # Mapping preference scores to verbs
    labels = ["hates", "dislikes", "is indifferent to", "likes", "loves"]

    # Create the preference map
    preference_map = dict(zip(pref_range, labels))

    def get_verb(score):
        if score in preference_map:
            return preference_map[score]
        else:
            raise ValueError(f"Error: Score '{score}' does not have a corresponding mapping in 'preference_map'. Please update the mapping.")

    # Process each row in the dataframe
    for index, row in dataframe.iterrows():
        table_image = Image.new("RGBA", (table_width, table_height + cell_height * 6), qualtrics_white)
        draw = ImageDraw.Draw(table_image)

        # Add "Here are the results from the first batch of tests"
        header_text = "Here are the results from the first batch of tests:"
        header_x = 10  # Left-justify the header
        header_y = 10
        draw.text((header_x, header_y), header_text, fill="black", font=header_font)
        y_offset = header_y + text_height + 20  # Add space below header

        # Draw chart and table
        # Draw a vertical black border between the text labels and the chemical images
        border_x = cell_width
        draw.line([(border_x, y_offset), (border_x, y_offset + table_height)], fill="black", width=20)

        # Draw a vertical black border at the end of the table
        end_border_x = table_width + 20
        draw.line([(end_border_x, y_offset), (end_border_x, y_offset + table_height)], fill="black", width=30)

        # Generate table for each chemical (A, B, C)
        for i, chemical in enumerate(["A", "B", "C"]):
            obs_success = int(row[f"Obs_{chemical}"])
            obs_failure = 5 - obs_success

            # Draw separating line above each row (starting at the image area only)
            line_y = i * cell_height + y_offset
            draw.line([(cell_width, line_y), (table_width, line_y)], fill="black", width=20)

            # Label each row
            row_label_x = 10
            row_label_y = line_y
            draw.text((row_label_x, row_label_y + cell_height // 2 - font_size // 2), f"Chemical {chemical}", fill="black", font=font)

            # Place chemical image in the first column
            table_image.paste(chemical_images[chemical], (row_label_x + cell_width, row_label_y))

            # Place images for successes
            for j in range(obs_success):
                x = (j + 2) * cell_width
                y = i * cell_height + y_offset
                table_image.paste(success_image, (x, y))

            # Place images for failures
            for j in range(obs_failure):
                x = (obs_success + j + 2) * cell_width
                y = i * cell_height + y_offset
                table_image.paste(failure_image, (x, y))

        # Draw a final line at the bottom of the table
        final_line_y = 3 * cell_height + y_offset
        draw.line([(cell_width, final_line_y), (table_width, final_line_y)], fill="black", width=20)

        y_offset = final_line_y + 40  # Add space below the table

        # Add a dark blue dashed line
        draw.line([(0, y_offset), (table_width, y_offset)], fill="darkblue", width=5)
        y_offset += 60  # Add space below the dashed line

        # Add "Here are Alex's preferences"
        preferences_header = "Here are Alex's preferences:"
        draw.text((header_x, y_offset), preferences_header, fill="black", font=header_font)
        y_offset += text_height + 20  # Add space below header

        # Add preferences
        for i, chemical in enumerate(["A", "B", "C"]):
            preference_text = f"Alex {get_verb(row[f'Preference_{chemical}']).upper()} "

            # Draw preference text aligned with `border_x`
            text_x = border_x + 10
            draw.text((text_x, y_offset), preference_text, fill="black", font=header_font)

            # Paste horizontal icon next to text
            icon_x = text_x + int(draw.textlength(preference_text, font=header_font)) + 10
            table_image.paste(chemical_horizontal_images[chemical], (icon_x, y_offset))

            # Update y_offset for next preference
            y_offset += text_height + 20

        # Crop to remove excess whitespace
        table_image = table_image.crop((0, 0, table_width, y_offset))

        output_path = OUTPUT / output_dir / f"{dataframe_name}_{index + 1}.png"
        output_path.parent.mkdir(parents=True, exist_ok=True)  # ensure directory exists
        table_image.save(output_path)

# Generate practice tables
create_practice_tables(attention, "attention_stim", "attention_stim")
create_practice_tables(practice, "practice_stim", "practice_stim")
create_practice_tables(control, "control_stim", "control_stim")
