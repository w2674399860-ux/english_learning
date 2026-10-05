from pydantic import BaseModel
from typing import Optional


class DegradableResponse(BaseModel):
    """降级标记：开发环境下服务不可用、回落 mock 时 degraded 为 true，reason 说明原因。
    未降级时 degraded 为 false、reason 为 null，两个字段始终返回。"""

    degraded: bool = False
    reason: Optional[str] = None
