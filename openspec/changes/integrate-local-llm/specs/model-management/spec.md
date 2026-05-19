## ADDED Requirements

### Requirement: 模型文件下载
系统 SHALL 支持从网络下载 GGUF 模型文件到应用私有目录。下载 SHALL 显示进度（已下载字节数/总字节数、百分比）。下载 SHALL 支持取消操作。

#### Scenario: 成功下载模型
- **WHEN** 调用 `downloadModel(url)` 且网络可用
- **THEN** 模型文件被下载到应用私有目录的 models/ 子目录
- **AND** 下载进度回调被持续调用，最终达到 100%
- **AND** 返回的本地文件路径指向下载完成的文件

#### Scenario: 下载过程中取消
- **WHEN** 调用 `downloadModel(url)` 后，在下载完成前调用 `cancelDownload()`
- **THEN** 下载任务被取消，部分下载的文件被删除
- **AND** 返回取消状态

#### Scenario: 网络不可用
- **WHEN** 调用 `downloadModel(url)` 但设备无网络连接
- **THEN** 立即返回失败状态，错误信息包含 "网络不可用"

### Requirement: 模型本地存储
系统 SHALL 将模型文件存储在应用私有目录（getApplicationDocumentsDirectory()/models/）。存储路径 SHALL 对 Dart 层可见，以便加载时传递路径给 FFI 层。

#### Scenario: 获取模型存储路径
- **WHEN** 调用 `getModelPath(modelName)`
- **THEN** 返回应用私有目录下的完整文件路径

#### Scenario: 检查模型文件是否存在
- **WHEN** 调用 `isModelAvailable(modelName)` 且文件已下载
- **THEN** 返回 true

#### Scenario: 检查未下载的模型
- **WHEN** 调用 `isModelAvailable(modelName)` 且文件未下载
- **THEN** 返回 false

### Requirement: 模型文件校验
系统 SHALL 在加载模型前进行基本校验：文件存在性、文件大小合理性（非空文件）。

#### Scenario: 校验有效模型文件
- **WHEN** 调用 `validateModel(path)` 且文件存在且大小大于 1MB
- **THEN** 返回校验通过

#### Scenario: 校验空文件
- **WHEN** 调用 `validateModel(path)` 且文件大小为 0
- **THEN** 返回校验失败，提示 "模型文件损坏"

### Requirement: 下载进度追踪
系统 SHALL 提供下载进度查询接口，支持获取当前下载任务的进度百分比和状态（等待中/下载中/已完成/失败/已取消）。

#### Scenario: 查询下载进度
- **WHEN** 模型正在下载中，调用 `getDownloadProgress()`
- **THEN** 返回当前进度百分比（0-100）和已下载字节数

#### Scenario: 查询空闲状态
- **WHEN** 没有正在进行的下载任务，调用 `getDownloadProgress()`
- **THEN** 返回状态为 idle，进度为 0
