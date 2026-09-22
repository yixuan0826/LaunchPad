"""临时探针：裁剪截图局部放大，方便肉眼核对细节。

用法：crop.py <图> <x> <y> <w> <h> <输出>
"""

import sys

from PySide6.QtGui import QImage

src, x, y, w, h, out = sys.argv[1:7]
image = QImage(src).copy(int(x), int(y), int(w), int(h))
image.scaled(image.width() * 2, image.height() * 2).save(out)
print(out, image.width(), image.height())
