/// 识别 / 生成流程所处的阶段。
/// 生成是一个请求（/learn/compose），没有流式输出，前端无法区分"写短文"与"挖空"，所以只有两个忙碌阶段。
enum FlowPhase { idle, recognizing, generating }
