import pandas as pd
import os
from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import yaml
import sys

ROOT_DIR = Path(__file__).resolve().parents[2]
sys.path.append(str(ROOT_DIR / "scripts" / "model_creation"))



from brute_force import define_pref_range

# Set up paths
ROOT_DIR = Path(__file__).resolve().parents[2]
IMG_DIR = ROOT_DIR / "resources" / "images"
FONT_DIR = ROOT_DIR / "resources" / "fonts"
CSV_PATH = ROOT_DIR / "data" / "derived" / "final_samples_v5.csv"
OUTPUT_DIR = ROOT_DIR / "figs"

# Load YAML config
with open(ROOT_DIR / "params.yaml", "r") as f:
    config = yaml.safe_load(f)

n = config["brute_force"]["n"]
z = config["brute_force"]["z"]
num_prefs = config["brute_force"]["num_prefs"]
pref_range = define_pref_range(z, num_prefs)

def create_pretty_tables(dataframe, output_dir=OUTPUT_DIR):
    output_dir.mkdir(parents=True, exist_ok=True)
    for file in output_dir.glob("*.png"):
        file.unlink()

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

    # Set fonts
    font_path = FONT_DIR / "arial.ttf"
    font_size = 50
    header_font_size = 80
    try:
        font = ImageFont.truetype(str(font_path), font_size)
        header_font = ImageFont.truetype(str(font_path), header_font_size)
    except:
        print("Warning: Custom font not found. Using default font.")
        font = ImageFont.load_default()
        header_font = font

    qualtrics_white = (255, 255, 255, 255)
    for key in chemical_images:
        chemical_images[key] = chemical_images[key].resize(success_image.size)
        filled_image = Image.new("RGBA", success_image.size, qualtrics_white)
        filled_image.paste(chemical_images[key], (0, 0), mask=chemical_images[key])
        chemical_images[key] = filled_image

    text_bbox = header_font.getbbox("Sample Text")
    text_height = text_bbox[3] - text_bbox[1]
    for key in chemical_horizontal_images:
        aspect_ratio = chemical_horizontal_images[key].width / chemical_horizontal_images[key].height
        new_width = int(aspect_ratio * text_height)
        resized_icon = chemical_horizontal_images[key].resize((new_width, text_height))
        filled_icon = Image.new("RGBA", resized_icon.size, qualtrics_white)
        filled_icon.paste(resized_icon, (0, 0), mask=resized_icon)
        chemical_horizontal_images[key] = filled_icon

    cell_width, cell_height = success_image.size
    table_width = cell_width * 6 + cell_width
    table_height = cell_height * 3
    preference_map = dict(zip(pref_range, ["hates", "dislikes", "is indifferent to", "likes", "loves"]))

    def get_verb(score):
        if score in preference_map:
            return preference_map[score]
        else:
            raise ValueError(f"Score '{score}' missing in preference map.")

    for index, row in dataframe.iterrows():
        table_image = Image.new("RGBA", (table_width, table_height + cell_height * 6), qualtrics_white)
        draw = ImageDraw.Draw(table_image)

        header_text = "Here are the results from the first batch of tests:"
        draw.text((10, 10), header_text, fill="black", font=header_font)
        y_offset = 10 + text_height + 20

        draw.line([(cell_width, y_offset), (cell_width, y_offset + table_height)], fill="black", width=20)
        draw.line([(table_width + 20, y_offset), (table_width + 20, y_offset + table_height)], fill="black", width=30)

        for i, chem in enumerate(["A", "B", "C"]):
            obs_success = int(row[f"Obs_{chem}"])
            obs_failure = 5 - obs_success
            row_label_y = i * cell_height + y_offset
            draw.line([(cell_width, row_label_y), (table_width, row_label_y)], fill="black", width=20)
            draw.text((10, row_label_y + cell_height // 2 - font_size // 2), f"Chemical {chem}", fill="black", font=font)
            table_image.paste(chemical_images[chem], (cell_width + 10, row_label_y))

            for j in range(obs_success):
                x = (j + 2) * cell_width
                y = i * cell_height + y_offset
                table_image.paste(success_image, (x, y))
            for j in range(obs_failure):
                x = (obs_success + j + 2) * cell_width
                y = i * cell_height + y_offset
                table_image.paste(failure_image, (x, y))

        final_line_y = 3 * cell_height + y_offset
        draw.line([(cell_width, final_line_y), (table_width, final_line_y)], fill="black", width=20)
        y_offset = final_line_y + 40
        draw.line([(0, y_offset), (table_width, y_offset)], fill="darkblue", width=5)
        y_offset += 60

        draw.text((10, y_offset), "Here are Alex's preferences:", fill="black", font=header_font)
        y_offset += text_height + 20

        for chem in ["A", "B", "C"]:
            pref_text = f"Alex {get_verb(row[f'Preference_{chem}']).upper()} "
            draw.text((cell_width + 10, y_offset), pref_text, fill="black", font=header_font)
            icon_x = cell_width + 10 + int(draw.textlength(pref_text, font=header_font)) + 10
            table_image.paste(chemical_horizontal_images[chem], (icon_x, y_offset))
            y_offset += text_height + 20

        table_image = table_image.crop((0, 0, table_width, y_offset))
        output_path = output_dir / f"trial_{index + 3}.png"
        table_image.save(output_path)

# Run script
data = pd.read_csv(CSV_PATH)
create_pretty_tables(data)
