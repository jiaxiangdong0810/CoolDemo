# Flutter Isolate 技术文档

> 面向 Flutter 小白:理解 Isolate 是什么、为什么需要、怎么用,以及本项目(端侧 LLM 推理)是如何借助 Isolate 让 UI 流畅不卡顿的。

---

## 第一部分:理解 Isolate

### 1.1 先搞清楚一个事实:Dart 是"单线程"的

写过 Java、Kotlin、C++ 的同学都熟悉"多线程"——一个进程里可以开很多线程,它们共享同一块内存,谁都能去读写同一个变量。

**Dart 不是这样的**。Dart 的代码默认全部跑在一个叫 **main isolate(主线程)** 的东西里。你写的 `setState`、`build`、点击按钮的回调、网络请求的 `await`……全部在这一个 isolate 里排队执行。

这就引出一个问题:**如果你在主 isolate 里写了一段耗时 5 秒的同步代码(比如解析一个超大 JSON、做矩阵运算、调用一个慢吞吞的 C++ 函数),会发生什么?**

答案是:**UI 直接冻住 5 秒**。动画不动、按钮按不动、滚动卡死。因为渲染下一帧的代码也在排队,被你那段耗时代码挡在了后面。

这就是为什么我们需要 Isolate。

---

### 1.2 Isolate 到底是什么?和 Thread 有什么区别?

可以把 isolate 理解为**"独立的 Dart 运行环境"**。每个 isolate 都有自己独立的:

- **内存堆(Heap)**:它的变量、对象,别人看不见也碰不到
- **事件循环(Event Loop)**:自己处理自己的任务队列
- **垃圾回收器(GC)**:自己管自己的内存

最关键的一句话:**isolate 之间不共享任何内存**。

这点和 Java 线程的差异是颠覆性的:

| 对比项 | Java/Kotlin 线程 | Dart Isolate |
|--------|------------------|--------------|
| 内存模型 | 共享内存 | 完全隔离,各管各的 |
| 通信方式 | 直接读写共享变量 | 只能通过"消息传递"(发邮件) |
| 同步问题 | 必须加锁(synchronized、Mutex) | 根本不存在,因为没共享 |
| 调试难度 | 容易死锁、竞态 | 几乎不会出现这两类问题 |

**为什么这么设计?** Dart 团队认为多线程共享内存 + 锁是软件工程里 bug 最多的地方,干脆禁止共享。这样开发者不用担心数据竞争,代价是 isolate 之间通信变"麻烦"了——必须发消息。

> 类比一下:线程像同一办公室里的同事,可以直接互相递东西。Isolate 像不同城市的两个公司,只能发快递。快递贵一点,但永远不会撞到对方的桌子。

---

### 1.3 Isolate 之间怎么通信?Port 机制

既然内存不共享,那两个 isolate 怎么协作?答案是 **Port(端口)**,本质上是消息队列。

核心概念有两个:

- **ReceivePort**:接收消息的"信箱",创建它的 isolate 才能从里面取信
- **SendPort**:发送消息用的"寄件地址",可以传给其他 isolate

它们成对出现:**每个 ReceivePort 自带一个 SendPort**(`receivePort.sendPort`)。你把 SendPort 交给别人,别人就能往你的 ReceivePort 里塞消息。

```
   主 Isolate                       Worker Isolate
   ┌─────────────┐                  ┌─────────────┐
   │ ReceivePort │ ◄──── 消息 ────  │  SendPort   │
   │             │                  │ (拿到的地址) │
   │  SendPort   │ ──── 消息 ────►  │ ReceivePort │
   │ (传过去的)   │                  │             │
   └─────────────┘                  └─────────────┘
```

发消息能传什么?基本类型(String、int、List、Map)、SendPort 本身、以及一些可序列化的对象。**不能直接传函数、不能传句柄、不能传指针**(因为内存不共享,传过去也访问不了)。

---

### 1.4 最简单的 Isolate 用法:`Isolate.run`

Dart 2.19+ 提供了一个极简 API,适合一次性耗时任务:

```dart
// 主 isolate
final result = await Isolate.run(() {
  // 这个闭包会在一个新的 isolate 里执行
  int sum = 0;
  for (int i = 0; i < 1000000000; i++) {
    sum += i;
  }
  return sum;
});
print(result); // 主 isolate 拿到结果
```

它的内部其实就是:开一个 isolate → 跑函数 → 把返回值通过 Port 传回来 → 关掉 isolate。一行搞定。

**适用场景**:一次性的、不需要持续交互的耗时任务。比如解析大 JSON、压缩图片、计算哈希。

**不适用场景**:需要反复调用、需要保持状态(比如"模型已加载")、需要持续推送数据的场景。这种就得用下面更底层的 `Isolate.spawn`。

---

### 1.5 进阶用法:`Isolate.spawn` + 长期存活的 Worker

`Isolate.spawn` 创建一个**长期运行**的 isolate,主 isolate 可以反复给它发任务。基本套路如下:

```dart
// 1. 主 isolate:启动 worker
final initPort = ReceivePort();
await Isolate.spawn(_workerEntry, initPort.sendPort);
final commandPort = await initPort.first as SendPort; // 拿到 worker 的指挥棒

// 2. 主 isolate:派任务
final replyPort = ReceivePort();
commandPort.send({'op': 'doWork', 'reply': replyPort.sendPort});
final result = await replyPort.first;

// ============================================================
// Worker isolate 那边
void _workerEntry(SendPort mainSendPort) {
  final commandPort = ReceivePort();
  mainSendPort.send(commandPort.sendPort); // 告诉主 isolate:用这个地址联系我

  commandPort.listen((message) {
    final msg = message as Map;
    if (msg['op'] == 'doWork') {
      // 干活...
      (msg['reply'] as SendPort).send('done');
    }
  });
}
```

这个"握手"过程看起来繁琐,但理解了就很简单:

1. 主 isolate 建一个 `initPort`,把它的 `sendPort` 交给 worker
2. worker 启动后,自己建一个 `commandPort`,把这个 port 的地址通过 `mainSendPort` 发回主 isolate
3. 双方此后就用 `commandPort` 持续通信

**为什么要"握手"?** 因为 `Isolate.spawn` 只能在创建时传一个参数过去。如果想双向通信,就必须用这种"先传一个 SendPort 过去,worker 再传一个 SendPort 回来"的方式。

---

### 1.6 Isolate 的代价:不是免费的

知道这些限制,才不会乱用:

- **启动开销**:开一个 isolate 大概 1-10 ms,有内存占用(几 MB 起步)
- **消息序列化**:发送复杂对象时会做深拷贝,大对象传过去很慢
- **不能共享对象**:你以为传过去的是引用,其实是拷贝(`TransferableTypedData` 等少数类型例外)

经验法则:**只把真正耗时的 CPU 密集型任务丢进 isolate**。普通的 `await http.get()` 不需要(网络等待不占 CPU,主 isolate 的事件循环本来就能处理)。

---

## 第二部分:本项目如何用 Isolate 优化性能

### 2.1 问题场景:LLM 推理为什么必须丢到 worker?

本项目要在手机上跑大语言模型(Qwen 系列 GGUF)。一次推理流程是:

```
用户输入 prompt
  → Dart 通过 FFI 调用 C++ 的 llama_wrapper
  → llama_wrapper 调 llama.cpp
  → llama.cpp 跑神经网络前向计算(大量矩阵乘法)
  → 生成 token,逐个返回
```

关键问题:**FFI 调用是同步的**。当 Dart 代码 `await llamaGenerate(...)` 时,虽然写了 `await`,但底下的 C++ 函数是**同步阻塞**地在跑——它不会主动让出执行权,Dart 的事件循环也没法切走。

如果这步在主 isolate 跑,会发生什么?

> 一次生成可能耗时几秒到几十秒。这期间 UI 完全冻结。用户输完字按发送 → 屏幕直接卡死十几秒 → 然后回复一次性蹦出来。完全不可用。

所以,**LLM 推理必须放到 worker isolate** 里执行。

---

### 2.2 项目的架构:一个常驻 Worker

代码在 `lib/services/llama_service.dart`。设计上是**一个长期存活的 worker isolate** 全程托管模型:

```
主 Isolate (UI 线程)                   Worker Isolate (推理线程)
┌──────────────────────┐               ┌──────────────────────┐
│  ChatPage / UI       │               │  持有 ctx (模型句柄)   │
│        ▼             │               │  执行 FFI 调用         │
│  ChatSession         │  command      │        ▼              │
│        ▼             │ ─────────►    │  llama.cpp 推理        │
│  LlamaService        │               │        ▼              │
│  (主 isolate 入口)    │  ◄─────────   │  返回结果 / 流式 token │
└──────────────────────┘   reply       └──────────────────────┘
```

为什么是"一个常驻"而不是"每次新建"?

- **模型加载非常贵**:加载一个 Qwen GGUF 模型要 1-3 秒、占用几百 MB 内存。每次新建 isolate 都重新加载,根本不能用。
- **模型状态必须在 worker 里**:`ctx`(模型上下文指针)是 C++ 的指针,**不能跨 isolate 传递**(内存不共享,指针在另一个 isolate 里指向空气)。所以模型必须"住在"持有它的那个 isolate 里。

---

### 2.3 启动 Worker:`_ensureWorker`(懒加载)

```dart
// llama_service.dart
SendPort? _commandPort;

Future<void> _ensureWorker() async {
  if (_commandPort != null) return;            // 已经启过了,直接返回

  final initPort = ReceivePort();
  await Isolate.spawn(
    _workerEntry,
    initPort.sendPort,
    debugName: 'llama-worker',
  );
  _commandPort = await initPort.first as SendPort;  // 握手:拿到 worker 的指挥棒
  initPort.close();
}
```

关键点:**懒启动 + 单例**。首次调用 `loadModel` 时才创建,之后所有调用复用同一个 worker。`_commandPort` 是主 isolate 给 worker 派任务用的地址,全局只有一个。

---

### 2.4 通信协议:命令-应答模式

项目设计了一套简单的消息协议。每次发命令带三样东西:

```dart
Future<dynamic> _send(Map<String, dynamic> request) async {
  await _ensureWorker();
  final replyPort = ReceivePort();           // ① 临时建一个回信信箱
  _commandPort!.send({
    ...request,
    'reply': replyPort.sendPort,             // ② 把回信地址附在消息里
  });
  final response = await replyPort.first as Map;  // ③ 等回信
  replyPort.close();

  if (response['ok'] == true) {
    return response['value'];
  }
  throw LlamaException(response['error'] as String);
}
```

为什么每次都新建一个 `replyPort` 而不是复用?

> 因为这样能**天然做到"请求-响应一一对应"**。每个请求都有自己的回信信箱,不会出现 A 请求的回复跑去给 B 用了。`await replyPort.first` 也能干净地拿到那一条回复就关闭信箱,不留垃圾。

Worker 那边接到消息就分发处理:

```dart
void _workerEntry(SendPort mainSendPort) {
  final commandPort = ReceivePort();
  mainSendPort.send(commandPort.sendPort);    // 握手:把我的地址给主 isolate

  Pointer<Void>? ctx;                          // 模型句柄,只活在这个 isolate 里

  commandPort.listen((message) {
    final msg = message as Map;
    final op = msg['op'] as String;
    final reply = msg['reply'] as SendPort?;

    try {
      switch (op) {
        case 'load':   ctx = _workerLoad(msg['path']);          ...
        case 'generate': ... 
        case 'stream':   ...
        case 'shutdown': Isolate.exit();
      }
    } catch (e, stack) {
      reply?.send({'ok': false, 'error': '$e\n$stack'});  // 出错也要回信,不能让主 isolate 干等
    }
  });
}
```

注意 `try/catch` 包住整个分发——**如果不捕获,worker 里的异常不会自动飞到主 isolate**,主 isolate 的 `await replyPort.first` 会永远 hang 住。这是 isolate 通信里最容易踩的坑。

---

### 2.5 难点:流式生成(双信箱设计)

普通生成是"发请求 → 等结果",但 LLM 流式生成不一样:**生成一个 token 就推一个出来**,UI 要实时显示。这时候一个 reply port 不够用了——总不能一个 token 回一封信然后关掉。

项目的解法是**两个 port 并存**:

```dart
Future<String> generateStream(
  String prompt, {
  required void Function(String token) onToken,
  ...
}) async {
  final tokenPort = ReceivePort();   // 信箱 A:专门接收 token 流
  final replyPort = ReceivePort();   // 信箱 B:接收"全部生成完了"的最终通知
  final buffer = StringBuffer();

  // 监听 token 流(异步、可持续)
  final tokenSub = tokenPort.listen((message) {
    final token = message as String;
    buffer.write(token);
    onToken(token);                  // 每来一个 token 就回调一次,UI 实时刷新
  });

  _commandPort!.send({
    'op': 'stream',
    'prompt': prompt,
    'tokenPort': tokenPort.sendPort, // 把两个地址都告诉 worker
    'reply': replyPort.sendPort,
    ...
  });

  try {
    await replyPort.first;           // 阻塞等待"生成结束"信号
    return buffer.toString();
  } finally {
    await tokenSub.cancel();         // 清理
    tokenPort.close();
    replyPort.close();
  }
}
```

数据流总览:

```
Worker 这边:                           主 isolate 这边:
llama.cpp 每生成一个 token             tokenPort 收到 → onToken → UI 刷新
  ↓                                     onToken → UI 刷新
通过 NativeCallable 回到 Dart           onToken → UI 刷新
  ↓                                     ...(持续多次)
tokenPort.send(token)  ─────────►      
                                       
所有 token 生成完                      replyPort 收到 "done" → 函数返回
  ↓
reply.send({'ok': true})  ─────────►   
```

**这里有个特别精巧的细节**——`NativeCallable.isolateLocal`:

```dart
final callback = NativeCallable<TokenCallbackC>.isolateLocal(
  (Pointer<Utf8> token, Pointer<Void> userData) {
    tokenPort.send(token.toDartString());
  },
);
```

`NativeCallable` 让 C++ 能反过来调 Dart 函数。`isolateLocal` 模式表示这个回调**就在 worker 当前所在的线程同步执行**,不走事件循环。这样 llama.cpp 每出一个 token,C++ 直接同步回调到这里,立刻通过 `tokenPort.send` 推回主 isolate,延迟最小。

---

### 2.6 优化效果对比

不用 isolate 会怎样:

| 场景 | 主 isolate 跑推理 | Worker isolate 跑推理 |
|------|-------------------|------------------------|
| 用户发消息 | UI 立即冻结 | 按钮反馈正常 |
| 加载动画 | 转不起来 | 流畅旋转 |
| 流式输出 | 看不到,一次性蹦出 | 一个字一个字打出来 |
| 中途想停 | 按钮按不动 | 随时点"停止" |
| 应用响应 | ANR(应用无响应) | 正常 60fps |

简单说一句:**没有 worker isolate,这个 App 根本跑不起来**。

---

### 2.7 还有什么可以学的设计

读 `llama_service.dart` 的时候,几个值得注意的细节:

1. **状态隔离**:`_isLoaded` 标记放在主 isolate 的 `LlamaService` 里,而真正的模型 `ctx` 指针放在 worker 里。两边各管各的视角,主 isolate 不需要知道 C++ 指针的存在。

2. **优雅关闭**:`dispose()` 发一个 `shutdown` 消息,worker 收到后先 `llamaWrapperFree(ctx)` 释放 C++ 资源,再 `Isolate.exit()`。如果直接 kill,C++ 那边的几百 MB 模型内存就泄漏了。

3. **停止信号走捷径**:`stopGeneration()` 没走 port,而是直接 `llamaSetStopFlag(1)`。为什么?因为 worker 正在 `_workerStream` 里同步阻塞跑推理,**根本不会处理新来的消息**——消息在队列里排着也没用。所以走 FFI 设置一个 C++ 端能看见的全局标志位,llama.cpp 内部循环每生成一个 token 检查一次,这样能立即中断。这是个非常实战的小技巧。

---

## 总结一句话

**Isolate 是 Dart 用来打破"单线程"限制的工具,代价是不能共享内存、必须用消息传递通信。** 本项目把 LLM 推理这种典型的 CPU 密集型同步任务放到一个常驻 worker isolate 里,通过"命令-应答" + "双 port 流式"的通信协议,既保证了 UI 流畅,又支持了流式输出和优雅停止。

掌握了 isolate,你就拥有了在 Flutter 里处理任何重计算任务的能力——不只是 LLM,图像处理、加解密、大数据解析,都是同一套套路。
