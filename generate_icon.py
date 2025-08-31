#!/usr/bin/env python3
import os
from PIL import Image, ImageDraw

# Create the assets directory if it doesn't exist
icon_dir = "MicOn/Assets.xcassets/AppIcon.appiconset"
os.makedirs(icon_dir, exist_ok=True)

# Icon sizes needed for macOS
sizes = [16, 32, 64, 128, 256, 512, 1024]

# Green color (similar to systemGreen)
green_color = (52, 199, 89)  # RGB for a nice green

for size in sizes:
    # Create a new image with transparent background
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    
    # Draw a green circle
    # Add a small margin for anti-aliasing
    margin = size * 0.05
    draw.ellipse(
        [margin, margin, size - margin, size - margin],
        fill=green_color,
        outline=None
    )
    
    # Save the image
    filename = f"{icon_dir}/icon_{size}.png"
    img.save(filename, 'PNG')
    print(f"Created {filename}")

print("All icons generated successfully!")