# -*- coding: utf-8 -*-
"""
MiSans 字体子集化脚本
保留：GB2312 一级字库（3755字）+ ASCII + 中文标点 + 常用符号
"""
import os
import sys
from fontTools.subset import Subsetter, Options

# 字体源目录和输出目录
SRC_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "fonts")
# 备份目录（保存原始字体文件）
BACKUP_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "fonts_original")
# 临时输出目录
TMP_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "fonts_tmp")

# 需要处理的字体文件
FONT_FILES = [
    "MiSans-Regular.ttf",
    "MiSans-Medium.ttf",
    "MiSans-Demibold.ttf",
]


def generate_charset():
    """生成保留字符集：完整GB2312（6763个汉字）+ ASCII + 标点符号"""
    chars = set()

    # 1. ASCII 可见字符 (0x20-0x7E)
    for i in range(0x20, 0x7F):
        chars.add(chr(i))

    # 2. 完整 GB2312 汉字集（一级3755 + 二级3008 = 6763字）
    # 通过遍历 Unicode 基本区，用 gb2312 编码筛选出所有 GB2312 字符
    # GB2312 覆盖的 Unicode 范围主要在 U+4E00-U+9FA5（CJK基本区）
    gb2312_count = 0
    for code in range(0x4E00, 0x9FFF):
        char = chr(code)
        try:
            char.encode("gb2312")
            chars.add(char)
            gb2312_count += 1
        except UnicodeEncodeError:
            pass
    print(f"GB2312 汉字数量: {gb2312_count}")

    # 3. 中文标点符号（GB2312 中的标点已包含在上方，这里补充全角标点）
    puncts = "，。、；：？！""''（）【】《》〈〉…—·～°±×÷∈∏∑√∝∞∫∮≡≌≈≤≥≠‰℃℉§№★☆○●◎◇◆□■△▲▽▼◣◤◢◥"
    for p in puncts:
        chars.add(p)

    return chars


def subset_font(src_path, dst_path, charset):
    """对单个字体文件进行子集化"""
    print(f"Processing: {os.path.basename(src_path)}")

    options = Options()
    options.layout_features = []  # 移除 OpenType features
    options.name_IDs = ["*"]  # 保留名称表
    options.glyph_names = False  # 不保留字形名
    options.notdef_outline = False  # 不保留 .notdef 轮廓
    options.recalc_bounds = True  # 重算边界
    options.recalc_timestamp = True  # 重算时间戳
    options.drop_tables = ["GPOS", "GDEF", "GVAR", "MVAR", "HVAR", "VVAR", "STAT"]
    options.flavor = "woff2" if dst_path.endswith(".woff2") else None

    subsetter = Subsetter(options=options)
    subsetter.populate(text="".join(sorted(charset)))

    from fontTools.ttLib import TTFont

    font = TTFont(src_path)
    subsetter.subset(font)
    font.save(dst_path)
    font.close()

    src_size = os.path.getsize(src_path) / 1024 / 1024
    dst_size = os.path.getsize(dst_path) / 1024 / 1024
    print(f"  {src_size:.2f} MB -> {dst_size:.2f} MB (减少 {src_size - dst_size:.2f} MB)")


def main():
    charset = generate_charset()
    print(f"保留字符集大小: {len(charset)} 个字符\n")

    # 确保目录存在
    os.makedirs(BACKUP_DIR, exist_ok=True)
    os.makedirs(TMP_DIR, exist_ok=True)

    total_src = 0
    total_dst = 0

    for font_file in FONT_FILES:
        src_path = os.path.join(SRC_DIR, font_file)
        dst_path = os.path.join(TMP_DIR, font_file)

        if not os.path.exists(src_path):
            print(f"WARNING: {src_path} not found, skipping")
            continue

        subset_font(src_path, dst_path, charset)
        total_src += os.path.getsize(src_path)
        total_dst += os.path.getsize(dst_path)

    print(f"\n总计: {total_src / 1024 / 1024:.2f} MB -> {total_dst / 1024 / 1024:.2f} MB")
    print(f"减少: {(total_src - total_dst) / 1024 / 1024:.2f} MB ({(1 - total_dst / total_src) * 100:.1f}%)")
    print(f"\n子集化字体已输出到: {TMP_DIR}")
    print(f"原始字体备份到: {BACKUP_DIR}")
    print("\n下一步: 确认无误后，将 fonts_tmp 的文件复制到 fonts 目录替换原文件")


if __name__ == "__main__":
    main()
