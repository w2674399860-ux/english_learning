"""E-4：模型输出解析函数 parse_ai_json。"""
import re

import pytest

from app.services import ai_service
from app.services.ai_service import AIParseError, parse_ai_json

KEYS = ("english", "chinese")
OBJ = '{"english": "Hi.", "chinese": "你好。"}'
EXPECTED = {"english": "Hi.", "chinese": "你好。"}


# ---- 六类输入 ---------------------------------------------------------------

def test_plain_json():
    assert parse_ai_json(OBJ, KEYS) == EXPECTED


def test_json_fence():
    assert parse_ai_json(f"```json\n{OBJ}\n```", KEYS) == EXPECTED


def test_bare_fence():
    assert parse_ai_json(f"```\n{OBJ}\n```", KEYS) == EXPECTED


def test_text_around_json():
    content = f"Sure! Here is the story:\n{OBJ}\nHope this helps."
    assert parse_ai_json(content, KEYS) == EXPECTED


def test_not_json():
    with pytest.raises(AIParseError, match="no JSON object found"):
        parse_ai_json("Sorry, I cannot help with that.", KEYS)


def test_missing_required_field():
    with pytest.raises(AIParseError, match="chinese"):
        parse_ai_json('{"english": "Hi."}', KEYS)


# ---- 边界 -------------------------------------------------------------------

@pytest.mark.parametrize("content", [None, 123, {"english": "Hi.", "chinese": "你好。"}])
def test_content_not_a_string(content):
    with pytest.raises(AIParseError, match="not a string"):
        parse_ai_json(content, KEYS)


def test_json_array_is_rejected():
    with pytest.raises(AIParseError, match="expected a JSON object"):
        parse_ai_json('["Hi.", "你好。"]', KEYS)


def test_non_string_field_is_rejected():
    with pytest.raises(AIParseError, match="english"):
        parse_ai_json('{"english": 42, "chinese": "你好。"}', KEYS)


def test_broken_json_inside_braces():
    with pytest.raises(AIParseError, match="invalid JSON"):
        parse_ai_json('Result: {"english": "Hi.", "chinese": }', KEYS)


def test_surrounding_whitespace():
    assert parse_ai_json(f"\n\n  ```json\n{OBJ}\n```  \n", KEYS) == EXPECTED


def test_extra_fields_are_kept():
    data = parse_ai_json('{"english": "Hi.", "chinese": "你好。", "note": "x"}', KEYS)
    assert data["note"] == "x"


# ---- 白盒：围栏剥离单独可用 -------------------------------------------------

@pytest.mark.parametrize("fence", ["```json", "```"])
def test_fence_stripping_works_without_regex_fallback(monkeypatch, fence):
    """贪婪正则 \\{.*\\} 目前会把带围栏的输入也兜住，只看输出的测试发现不了围栏剥离被删。

    这里禁用正则回退，证明围栏剥离自己能解析。以后把正则改成非贪婪或按括号配对时，
    带围栏的输出将主要依赖这条路径。
    """
    monkeypatch.setattr(ai_service, "_OBJECT_RE", re.compile(r"(?!x)x"))
    assert parse_ai_json(f"{fence}\n{OBJ}\n```", KEYS) == EXPECTED
