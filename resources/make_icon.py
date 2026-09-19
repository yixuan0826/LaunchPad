#!/usr/bin/env python3
"""Generate ICO from qtawesome icon for Windows build."""

import sys
from pathlib import Path

try:
    import qtawesome as qta
    from PySide6.QtGui import QIcon, QPixmap
    from PySide6.QtCore import QIODevice, QByteArray, QBuffer
    from PySide6.QtWidgets import QApplication
except ImportError:
    print("Installing required packages...")
    import subprocess
    subprocess.run([sys.executable, "-m", "pip", "install", "qtawesome", "PySide6"], check=True)
    import qtawesome as qta
    from PySide6.QtGui import QIcon, QPixmap
    from PySide6.QtCore import QIODevice, QByteArray, QBuffer
    from PySide6.QtWidgets import QApplication

def generate_ico():
    app = QApplication.instance() or QApplication(sys.argv)
    
    ico_path = Path(__file__).parent / "icon.ico"
    
    # Generate icon using qtawesome
    icon = qta.icon("fa5s.rocket", color="white", options=[{'scale_factor': 1.2}])
    
    # Create multiple sizes
    sizes = [16, 24, 32, 48, 64, 128, 256]
    
    # Save as ICO using PIL
    try:
        from PIL import Image
        import io
    except ImportError:
        import subprocess
        subprocess.run([sys.executable, "-m", "pip", "install", "pillow"], check=True)
        from PIL import Image
        import io
    
    images = []
    for size in sizes:
        pixmap = icon.pixmap(size, size)
        # Convert to PIL Image using QBuffer
        buffer = QBuffer()
        buffer.open(QIODevice.OpenModeFlag.WriteOnly)
        pixmap.save(buffer, "PNG")
        
        # Convert QByteArray to bytes
        data = bytes(buffer.data())
        buffer.close()
        
        img = Image.open(io.BytesIO(data))
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