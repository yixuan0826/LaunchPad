#!/usr/bin/env python3
"""Generate ICO from SVG for Windows build."""

import sys
from pathlib import Path

try:
    from cairosvg import svg2png
    from PIL import Image
except ImportError:
    print("Installing required packages...")
    import subprocess
    subprocess.run([sys.executable, "-m", "pip", "install", "cairosvg", "pillow"], check=True)
    from cairosvg import svg2png
    from PIL import Image

def generate_ico():
    svg_path = Path(__file__).parent / "icon.svg"
    ico_path = Path(__file__).parent / "icon.ico"
    
    if not svg_path.exists():
        print(f"SVG not found: {svg_path}")
        return False
    
    # Generate multiple sizes
    sizes = [16, 24, 32, 48, 64, 128, 256]
    images = []
    
    for size in sizes:
        png_data = svg2png(url=str(svg_path), output_width=size, output_height=size)
        img = Image.open(open(png_data, 'rb') if hasattr(png_data, 'read') else png_data)
        # Actually cairosvg returns bytes
        import io
        img = Image.open(io.BytesIO(png_data))
        images.append(img)
    
    # Save as ICO
    images[0].save(
        ico_path,
        format='ICO',
        sizes=[(img.width, img.height) for img in images],
        append_images=images[1:]
    )
    
    print(f"Generated: {ico_path}")
    return True

if __name__ == "__main__":
    generate_ico()