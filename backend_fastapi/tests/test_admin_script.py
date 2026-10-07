"""scripts/admin.py（只连测试库）：确认流程、密码输入、会话撤销、3306 防护。"""
import pytest
from conftest import DEFAULT_PASSWORD, bearer, register

from scripts import admin

NEW_PASSWORD = "admin-reset-pass-9"


def run(monkeypatch, capsys, argv, inputs=(), passwords=()):
    inputs, passwords = list(inputs), list(passwords)
    monkeypatch.setattr("builtins.input", lambda prompt="": inputs.pop(0))
    monkeypatch.setattr(admin.getpass, "getpass", lambda prompt="": passwords.pop(0))
    code = admin.main(["--target", "test", *argv])
    out = capsys.readouterr().out
    return code, out


def me_status(client, token):
    return client.get("/api/v1/auth/me", headers=bearer(token)).status_code


def test_reset_password_revokes_sessions(db_client, monkeypatch, capsys):
    token = register(db_client, "alice")["token"]
    code, out = run(monkeypatch, capsys, ["reset-password", "Alice"], inputs=["alice"],
                    passwords=[NEW_PASSWORD, NEW_PASSWORD])
    assert code == 0, out
    assert "english_learning_test" in out
    assert NEW_PASSWORD not in out
    assert me_status(db_client, token) == 401
    login = db_client.post("/api/v1/auth/login", json={"username": "alice", "password": NEW_PASSWORD})
    assert login.status_code == 200


@pytest.mark.parametrize("inputs, passwords, message", [
    (["bob"], [], "用户名不一致"),
    (["alice"], [NEW_PASSWORD, NEW_PASSWORD + "x"], "两次输入不一致"),
    (["alice"], ["short", "short"], "密码至少 8 位"),
])
def test_reset_password_cancelled(db_client, monkeypatch, capsys, inputs, passwords, message):
    token = register(db_client, "alice")["token"]
    code, out = run(monkeypatch, capsys, ["reset-password", "alice"], inputs=inputs, passwords=passwords)
    assert code == 1 and message in out
    assert me_status(db_client, token) == 200
    login = db_client.post("/api/v1/auth/login", json={"username": "alice", "password": DEFAULT_PASSWORD})
    assert login.status_code == 200


def test_disable_and_enable(db_client, monkeypatch, capsys):
    token = register(db_client, "alice")["token"]
    assert run(monkeypatch, capsys, ["disable", "alice"], inputs=["alice"])[0] == 0
    assert me_status(db_client, token) == 401
    assert db_client.post("/api/v1/auth/login",
                          json={"username": "alice", "password": DEFAULT_PASSWORD}).status_code == 403

    assert run(monkeypatch, capsys, ["enable", "alice"], inputs=["alice"])[0] == 0
    assert db_client.post("/api/v1/auth/login",
                          json={"username": "alice", "password": DEFAULT_PASSWORD}).status_code == 200


def test_unknown_user(db_client, monkeypatch, capsys):
    code, out = run(monkeypatch, capsys, ["disable", "ghost"])
    assert code == 1 and "不存在" in out


def test_list_users_is_read_only(db_client, monkeypatch, capsys):
    register(db_client, "alice")
    code, out = run(monkeypatch, capsys, ["list-users"])
    assert code == 0 and "alice" in out and "共 1 个用户" in out
    assert "$argon2" not in out


def test_cleanup_sessions_dry_run(db_client, monkeypatch, capsys):
    code, out = run(monkeypatch, capsys, ["cleanup-sessions", "--dry-run"])
    assert code == 0 and "[dry-run]" in out


def test_refuses_local_3306(monkeypatch, capsys):
    monkeypatch.setattr(admin.settings, "database_url", "mysql+asyncmy://u:secretpw@127.0.0.1:3306/english_learning")
    code = admin.main(["list-users"])
    out = capsys.readouterr().out
    assert code == 2 and "拒绝执行" in out and "secretpw" not in out
