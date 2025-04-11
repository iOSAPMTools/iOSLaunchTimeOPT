cmake_minimum_required(VERSION 3.13.4) # 根据你的 CMake 版本调整
project(LaunchGuardPlugin CXX)

# --- 查找 Clang/LLVM ---
# 需要确保你的环境已配置好，CMake 能找到 LLVM/Clang
# 通常通过 LLVM_DIR 环境变量或 CMake 传递 -DLLVM_DIR=/path/to/llvm-install/lib/cmake/llvm
find_package(LLVM REQUIRED CONFIG)
find_package(Clang REQUIRED CONFIG)

# 添加 LLVM/Clang 头文件路径
include_directories(${LLVM_INCLUDE_DIRS})
include_directories(${CLANG_INCLUDE_DIRS})
add_definitions(${LLVM_DEFINITIONS})

# --- 定义插件目标 ---
# 将所有 .cpp 文件添加到源文件列表
file(GLOB PLUGIN_SOURCES "*.cpp")

# 添加插件目标，编译为共享库 (dylib on macOS)
add_library(LaunchGuardPlugin MODULE ${PLUGIN_SOURCES})

# --- 链接必要的 Clang/LLVM 库 ---
# 基础库
target_link_libraries(LaunchGuardPlugin PRIVATE
  clangAST
  clangBasic
  clangFrontend
  clangTooling # 如果需要用到 LibTooling 功能
  LLVMCore
  LLVMSupport
)

# 如果 LLVM 是作为共享库构建的，可能需要这个
if(LLVM_LINK_LLVM_DYLIB)
  target_link_options(LaunchGuardPlugin PRIVATE "-Wl,-rpath,${LLVM_LIBRARY_DIR}")
  target_link_libraries(LaunchGuardPlugin PRIVATE LLVM)
endif()

# --- 其他设置 ---
set(CMAKE_CXX_STANDARD 17) # 推荐使用 C++17 或更高版本
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 插件需要关闭 RTTI (Run-Time Type Information) 以匹配 LLVM
set_target_properties(LaunchGuardPlugin PROPERTIES
  CXX_VISIBILITY_PRESET hidden
  HIP_ARCHITECTURES OFF # 如果你的 CMake 支持 HIP
)
if(NOT MSVC)
  target_compile_options(LaunchGuardPlugin PRIVATE -fno-rtti)
endif()

# --- 安装 (可选) ---
# 可以定义安装规则，将插件库安装到指定位置
# install(TARGETS LaunchGuardPlugin LIBRARY DESTINATION lib)

# --- 输出信息 ---
message(STATUS "LLVM include dirs: ${LLVM_INCLUDE_DIRS}")
message(STATUS "Clang include dirs: ${CLANG_INCLUDE_DIRS}")
message(STATUS "LLVM library dir: ${LLVM_LIBRARY_DIR}") # 仅作调试信息 