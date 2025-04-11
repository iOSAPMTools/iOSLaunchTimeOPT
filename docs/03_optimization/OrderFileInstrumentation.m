// OrderFileInstrumentation.m
// 将此文件添加到你的 App Target，并确保它只在特定的 "Instrumented" 构建配置下编译。
// 你需要在 "Instrumented" 配置的 Build Settings -> Preprocessor Macros 中定义一个宏，例如 ORDER_FILE_INSTRUMENTATION=1
// 或者在 Build Phases -> Compile Sources 中为该文件设置特定的配置。

#ifdef ORDER_FILE_INSTRUMENTATION // 只在插桩配置下编译

#import <Foundation/Foundation.h>
#include <dlfcn.h> // For dladdr
#include <libkern/OSAtomic.h> // For OSAtomicFifoQueue
#include <pthread.h>

// 使用原子队列来收集符号，减少锁竞争
// 注意队列大小，如果启动路径非常长，可能需要增大
#define SYMBOL_QUEUE_SIZE (1 << 20) // 大约 100 万个符号

// 定义队列节点结构
typedef struct {
    void *pc; // 函数调用地址 (Program Counter)
    void *next; // 指向下一个节点 (用于 FIFO 队列)
} SymbolNode;

// 定义 FIFO 队列头结构
OSQueueHead symbolQueue = OS_FIFO_QUEUE_INITIALIZER;
// 预分配节点内存池，避免在回调中频繁 malloc (回调需要尽可能快)
static SymbolNode symbolNodePool[SYMBOL_QUEUE_SIZE];
// 原子计数器，用于从内存池分配节点
static volatile int32_t nodePoolIndex = 0;

// 后台线程，负责将队列中的符号写入文件
static pthread_t writeThread;
static volatile BOOL writingActive = NO;
static NSString *symbolFilePath = nil; // 符号文件路径

// 后台线程函数
static void* writeSymbolsToFile(void *context) {
    NSMutableArray<NSString *> *symbols = [NSMutableArray array];
    FILE *file = NULL;

    while (writingActive || OSAtomicDequeue(&symbolQueue, offsetof(SymbolNode, next)) != NULL) {
        SymbolNode *node;
        while ((node = OSAtomicDequeue(&symbolQueue, offsetof(SymbolNode, next))) != NULL) {
            Dl_info info;
            if (dladdr(node->pc, &info) && info.dli_sname) {
                NSString *symbolName = @(info.dli_sname);
                // 可选：进行一些过滤，例如去除 C++ 析构函数等可能不需要的符号
                 if (![symbolName containsString:@"::~"] && ![symbolName containsString:@"CXAAtExit"]) {
                     [symbols addObject:symbolName];
                 }
            }
            // 将节点放回内存池 (简单处理，不实际放回，依赖于数量足够)
            // 理想情况下需要更复杂的内存池管理
        }

        // 批量写入文件，减少 IO 次数
        if (symbols.count > 0) {
            if (!file) {
                file = fopen(symbolFilePath.UTF8String, "a"); // 追加模式
                if (!file) {
                    NSLog(@"[OrderFile] Error:无法打开符号文件: %@", symbolFilePath);
                    // 停止写入，避免无限循环错误日志
                    writingActive = NO;
                    break;
                }
            }
            // 将符号写入文件，每个符号一行
            for (NSString *symbol in symbols) {
                fprintf(file, "%s\n", symbol.UTF8String);
            }
            [symbols removeAllObjects]; // 清空已写入的符号
            fflush(file); // 确保写入磁盘
        }

        // 如果队列空了，稍微等待一下
        usleep(100000); // 100ms
    }

    if (file) {
        fclose(file);
        NSLog(@"[OrderFile] 符号写入完成: %@", symbolFilePath);
    } else if (writingActive) { // 如果是因为文件打不开而退出
         NSLog(@"[OrderFile] Error: 因无法打开文件，符号写入线程退出。");
    } else {
         NSLog(@"[OrderFile] 符号写入线程正常退出。");
    }

    return NULL;
}

// Clang 插桩回调函数
// 注意：此函数必须是 C 函数，不能是 Objective-C 方法
void __sanitizer_cov_trace_pc_guard_init(uint32_t *start, uint32_t *stop) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 初始化符号文件路径
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        symbolFilePath = [documentsDirectory stringByAppendingPathComponent:@"app_launch.order.raw"]; // 原始符号文件

        // 尝试删除旧文件
        [[NSFileManager defaultManager] removeItemAtPath:symbolFilePath error:nil];
        NSLog(@"[OrderFile] 初始化符号记录，将写入到: %@", symbolFilePath);

        // 启动后台写入线程
        writingActive = YES;
        pthread_create(&writeThread, NULL, writeSymbolsToFile, NULL);
    });
}

void __sanitizer_cov_trace_pc_guard(uint32_t *guard) {
    // `guard` 参数在这里通常不直接使用，我们关心的是调用此函数时的 PC (Program Counter)
    // 使用 __builtin_return_address(0) 获取调用者地址 (即触发 guard 的函数地址)
    void *pc = __builtin_return_address(0);

    // 从内存池获取一个节点
    int32_t currentIndex = OSAtomicIncrement32(&nodePoolIndex) - 1;
    if (currentIndex < SYMBOL_QUEUE_SIZE) {
        SymbolNode *node = &symbolNodePool[currentIndex];
        node->pc = pc;
        // 将节点放入原子队列
        OSAtomicEnqueue(&symbolQueue, node, offsetof(SymbolNode, next));
    } else {
        // 内存池耗尽，放弃记录，可能需要增大 SYMBOL_QUEUE_SIZE
        // 避免在这里打印日志，会严重影响性能
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSLog(@"[OrderFile] Warning: 符号节点池耗尽，后续符号可能丢失！请考虑增大 SYMBOL_QUEUE_SIZE。");
        });
    }
}

// (可选) 提供一个函数来停止后台线程，例如在 App 进入后台或特定时机调用
void stopOrderFileWriting(void) {
    if (writingActive) {
        writingActive = NO; // 通知后台线程停止
        // 等待后台线程结束 (可以设置超时)
        // pthread_join(writeThread, NULL); // 在主线程调用 join 可能卡死，最好异步处理
        NSLog(@"[OrderFile] 发出停止写入信号。");
    }
}

#endif // ORDER_FILE_INSTRUMENTATION