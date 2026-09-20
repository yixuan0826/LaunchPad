#!/usr/bin/env python3
"""Generate assets/icon.ico and assets/icon.png from the Lawnicons app mark.

Run:  python scripts/build_icon.py

The Lawnicons SVG is monochrome (black strokes on a transparent 192x192 canvas),
so the mark is rendered into an alpha mask and refilled in white on top of the
Fluent accent tile — that is what turns it into a usable Windows app icon.
"""

from __future__ import annotations

import struct
import sys
from pathlib import Path

from PySide6.QtCore import QBuffer, QRectF, Qt
from PySide6.QtGui import QColor, QGuiApplication, QImage, QLinearGradient, QPainter, QPainterPath
from PySide6.QtSvg import QSvgRenderer

ROOT = Path(__file__).resolve().parent.parent
MARK = ROOT / "assets" / "icons" / "lawnicons" / "honkai_star_rail.svg"
ICO_PATH = ROOT / "assets" / "icon.ico"
PNG_PATH = ROOT / "assets" / "icon.png"

ICO_SIZES = (16, 24, 32, 48, 64, 128, 256)
TILE_TOP = "#4cc2ff"
TILE_BOTTOM = "#0067c0"
TILE_RADIUS = 0.22  # fraction of the edge
MARK_INSET = 0.20  # padding around the mark, as a fraction of the edge


def _mark_mask(size: int) -> QImage:
    """Render the SVG at *size*, then recolour every painted pixel to white."""
    mask = QImage(size, size, QImage.Format_ARGB32_Premultiplied)
    mask.fill(Qt.transparent)

    painter = QPainter(mask)
    painter.setRenderHint(QPainter.Antialiasing)
    QSvgRenderer(str(MARK)).render(painter, QRectF(0, 0, size, size))
    painter.end()

    painter = QPainter(mask)
    painter.setCompositionMode(QPainter.CompositionMode_SourceIn)
    painter.fillRect(mask.rect(), Qt.white)
    painter.end()
    return mask


def render(size: int) -> QImage:
    image = QImage(size, size, QImage.Format_ARGB32_Premultiplied)
    image.fill(Qt.transparent)

    painter = QPainter(image)
    painter.setRenderHint(QPainter.Antialiasing)
    painter.setRenderHint(QPainter.SmoothPixmapTransform)

    tile = QPainterPath()
    tile.addRoundedRect(QRectF(0, 0, size, size), size * TILE_RADIUS, size * TILE_RADIUS)
    gradient = QLinearGradient(0, 0, 0, size)
    gradient.setColorAt(0.0, QColor(TILE_TOP))
    gradient.setColorAt(1.0, QColor(TILE_BOTTOM))
    painter.fillPath(tile, gradient)

    inset = size * MARK_INSET
    painter.drawImage(QRectF(inset, inset, size - inset * 2, size - inset * 2), _mark_mask(size))
    painter.end()
    return image


def _png_bytes(image: QImage) -> bytes:
    buffer = QBuffer()
    buffer.open(QBuffer.WriteOnly)
    image.save(buffer, "PNG")
    return bytes(buffer.data())


def write_ico(images: list[QImage], path: Path) -> None:
    """Write a multi-resolution .ico whose frames are PNG-compressed."""
    payloads = [_png_bytes(image) for image in images]

    header = struct.pack("<HHH", 0, 1, len(images))
    offset = len(header) + 16 * len(images)

    entries = b""
    blobs = b""
    for image, payload in zip(images, payloads):
        edge = 0 if image.width() >= 256 else image.width()  # 0 means 256 in the ICO header
        entries += struct.pack("<BBBBHHII", edge, edge, 0, 0, 1, 32, len(payload), offset)
        blobs += payload
        offset += len(payload)

    path.write_bytes(header + entries + blobs)


def main() -> int:
    QGuiApplication(sys.argv)  # QImage/QPainter need a Qt application instance
    if not MARK.is_file():
        print(f"missing mark: {MARK}", file=sys.stderr)
        return 1

    images = [render(size) for size in ICO_SIZES]
    for size, image in zip(ICO_SIZES, images):
        if image.isNull():
            print(f"failed to render {size}px", file=sys.stderr)
            return 1

    write_ico(images, ICO_PATH)
    images[-1].save(str(PNG_PATH), "PNG")

    print(f"wrote {ICO_PATH.relative_to(ROOT)} "
          f"({ICO_PATH.stat().st_size} bytes, sizes {', '.join(map(str, ICO_SIZES))})")
    print(f"wrote {PNG_PATH.relative_to(ROOT)} ({PNG_PATH.stat().st_size} bytes, 256x256)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
