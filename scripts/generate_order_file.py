#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import argparse
import sys
import os

def generate_order_file(raw_symbol_file, output_order_file):
    """
    读取包含原始符号列表的文件，去重后生成最终的 .order 文件。
    原始文件每行一个符号名。
    """
    if not os.path.exists(raw_symbol_file):
        print(f"错误：原始符号文件不存在: {raw_symbol_file}", file=sys.stderr)
        return False

    print(f"正在读取原始符号文件: {raw_symbol_file}")
    symbols_seen = set()
    ordered_symbols = []

    try:
        with open(raw_symbol_file, 'r') as f_raw:
            for line in f_raw:
                symbol = line.strip()
                # 跳过空行和可能的错误/日志行
                if symbol and not symbol.startswith("[OrderFile]"):
                    # 使用 set 来自动处理重复项，同时保留首次出现的顺序
                    if symbol not in symbols_seen:
                        symbols_seen.add(symbol)
                        ordered_symbols.append(symbol)

        print(f"读取完成，共找到 {len(ordered_symbols)} 个唯一符号。")

        print(f"正在生成 Order File: {output_order_file}")
        with open(output_order_file, 'w') as f_order:
            for symbol in ordered_symbols:
                f_order.write(symbol + '\n')

        print("Order File 生成成功！")
        return True

    except Exception as e:
        print(f"处理文件时发生错误: {e}", file=sys.stderr)
        return False

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="从原始符号列表文件生成 Xcode Order File (.order)。")
    parser.add_argument("raw_file", help="包含原始符号列表的文件路径 (由 OrderFileInstrumentation.m 生成)。")
    parser.add_argument("-o", "--output", default="app.order",
                        help="输出的 .order 文件路径 (默认: app.order)。")
    args = parser.parse_args()

    if generate_order_file(args.raw_file, args.output):
        sys.exit(0)
    else:
        sys.exit(1) 