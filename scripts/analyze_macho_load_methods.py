#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import lief # 需要先安装 pip install lief
import argparse
import sys
import logging

# 配置日志
logging.basicConfig(level=logging.INFO, format='%(levelname)s: %(message)s')

def find_load_methods_classes(macho_path):
    """
    分析 Mach-O 文件，查找可能包含 +load 方法的 Objective-C 类。
    主要通过查找 __objc_nlclslist (非懒加载类列表) 段来识别。
    """
    try:
        # 解析 Mach-O 文件
        binary = lief.parse(macho_path)
        if not binary:
            logging.error(f"无法解析 Mach-O 文件: {macho_path}")
            return None

        if not isinstance(binary, lief.MachO.Binary):
             logging.error(f"文件不是有效的 Mach-O 格式: {macho_path}")
             return None

        logging.info(f"开始分析文件: {macho_path}")

        # 查找 __DATA,__objc_nlclslist section
        # 这个 section 包含了 non-lazy classes 的指针列表，这些类通常实现了 +load 方法
        nlclslist_section = binary.get_section("__objc_nlclslist")

        if not nlclslist_section:
            logging.info("未找到 __objc_nlclslist section，可能没有显式的 +load 方法，或者 App 完全基于 Swift。")
            return []

        logging.info(f"找到 __objc_nlclslist section (大小: {nlclslist_section.size} bytes)")

        # __objc_nlclslist 包含指向类对象的指针列表 (通常是 8 字节每个指针 for arm64)
        # 每个类对象 (objc_class) 的结构比较复杂，其中包含指向 class_ro_t 的指针
        # class_ro_t 包含了方法列表等信息。
        # 直接从 section 内容解析出类名比较复杂，且容易出错。
        # 一个更可靠（但仍是间接）的方法是：列出所有类，然后看哪些类出现在 non-lazy list 中。
        # LIEF 目前似乎没有直接提供解析 __objc_nlclslist 指向的类的功能。
        #
        # 另一种稍微简化但有效的策略是：
        # 查找所有 Objective-C 类，然后检查它们的 flags 或元信息，看是否有标记表明它们有 +load。
        # LIEF 的 `binary.objc_classes` 可以获取所有类。

        potential_load_classes = []
        if hasattr(binary, 'objc_classes') and binary.objc_classes:
            logging.info(f"共找到 {len(binary.objc_classes)} 个 Objective-C 类。正在检查...")
            for objc_class in binary.objc_classes:
                # class_ro_t 的 flags 中有一个 RO_HAS_LOAD_METHOD 位
                # LIEF 目前（截至 0.12.x）可能没有直接暴露这个 flag 的解析
                # 我们先采用一个常见但可能不完全准确的假设：
                # 如果一个类出现在 __objc_nlclslist 中，它很可能实现了 +load
                # (虽然理论上可以没有 +load 但仍被标记为 non-lazy，但这很少见)
                #
                # 我们需要找到一种方法将 nlclslist section 中的指针与 LIEF 解析出的类关联起来。
                # 这通常需要处理虚拟地址 (VA) 和文件偏移。
                #
                # 简化策略：先列出所有类，并标记哪些可能是 non-lazy。
                # 精确查找需要更深入的解析，可能需要结合其他工具或手动分析。
                #
                # !! 临时策略：目前 LIEF 难以直接关联 nlclslist 和具体类名，
                # !! 我们先列出所有找到的 Objective-C 类作为初步排查范围。
                # !! 精确识别哪些类 *真正* 在 nlclslist 里需要更复杂的地址映射。
                # !! 对于大型项目，这个列表可能很长。
                potential_load_classes.append(objc_class.name)

            # 如果能精确识别，这里的逻辑会更复杂。
            # 暂时无法通过 LIEF 直接判断 RO_HAS_LOAD_METHOD 或关联 nlclslist，
            # 所以我们返回所有 OC 类名作为潜在目标。用户需要进一步结合其他工具验证。
            logging.warning("当前脚本暂时列出所有 Objective-C 类作为排查范围。")
            logging.warning("精确识别含 +load 的类需要更复杂的 Mach-O 分析或使用其他工具 (如 Hopper Disassembler, IDA Pro)。")

        else:
            logging.info("在 Mach-O 文件中未找到 Objective-C 类信息。")

        return sorted(list(set(potential_load_classes))) # 去重并排序

    except lief.bad_file as e:
        logging.error(f"读取或解析文件时出错: {e}")
        return None
    except Exception as e:
        logging.error(f"发生未知错误: {e}")
        return None

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="分析 iOS Mach-O 可执行文件，查找可能包含 +load 方法的 Objective-C 类。")
    parser.add_argument("macho_file", help="指向 iOS 应用可执行文件的路径 (例如: YourApp.app/YourApp)")
    args = parser.parse_args()

    if not lief.__version__:
         print("错误：看起来 lief 库没有正确安装或导入。", file=sys.stderr)
         sys.exit(1)

    logging.info(f"使用 LIEF 版本: {lief.__version__}")
    class_list = find_load_methods_classes(args.macho_file)

    if class_list is not None:
        if class_list:
            print("\n找到可能包含 +load 方法的 Objective-C 类 (或需要排查的类列表):")
            for class_name in class_list:
                print(f"- {class_name}")
            # print("\n注意：此列表基于对 Mach-O 结构的分析，可能包含非直接实现 +load 但仍需关注的类。")
            # print("建议结合 Instruments (App Launch), 日志或静态分析工具进一步确认。")
        else:
            print("\n未找到明确的 Objective-C 类或包含 +load 方法的迹象。")
        sys.exit(0)
    else:
        print(f"\n分析失败，请检查文件路径和文件格式。")
        sys.exit(1) 