"""管理员命令行（在 backend_fastapi\\ 下运行）。

    venv\\Scripts\\python -m scripts.admin list-users
    venv\\Scripts\\python -m scripts.admin reset-password <用户名>
    venv\\Scripts\\python -m scripts.admin disable <用户名>
    venv\\Scripts\\python -m scripts.admin enable <用户名>
    venv\\Scripts\\python -m scripts.admin cleanup-sessions [--dry-run]
    venv\\Scripts\\python -m scripts.admin cleanup-rate-limits [--dry-run]

防误操作：
- 执行前打印目标库（主机:端口/库名，不含密码）与目标用户当前状态
- 写操作必须再输入一次用户名确认，没有跳过确认的参数
- 默认操作开发库；测试库需显式 --target test；拒绝连接本机 3306（check_database_url）
- 新密码只用 getpass 输入两次，不出现在命令行参数、屏幕与日志中
- 每个写操作在一个事务里完成，出错整体回滚
"""
import argparse
import asyncio
import getpass
import sys

from sqlalchemy import select
from sqlalchemy.engine import make_url
from sqlalchemy.ext.asyncio import async_sessionmaker
from sqlalchemy.pool import NullPool

from app.auth.passwords import AuthRuleError, normalize_login_username
from app.auth.service import AuthService
from app.core.config import settings
from app.db.session import DatabaseConfigError, make_engine
from app.models.user import User
from app.ratelimit import limiter
from app.schemas.common import to_utc_iso


def _target_url(target: str) -> str:
    url = settings.test_database_url if target == "test" else settings.database_url
    if target == "test" and make_url(url or "mysql://x/none").database != "english_learning_test":
        raise DatabaseConfigError("test target must use database 'english_learning_test'")
    return url


def _describe(url: str) -> str:
    u = make_url(url)
    return f"{u.host}:{u.port}/{u.database}"


def _fmt(dt) -> str:
    return to_utc_iso(dt) if dt else "-"


def _confirm(username: str, action: str) -> bool:
    typed = input(f"确认对用户 {username!r} 执行「{action}」？请再输入一次用户名：").strip().lower()
    if typed != username:
        print("用户名不一致，已取消。")
        return False
    return True


def _read_new_password(username: str) -> str | None:
    from app.auth.passwords import validate_new_password

    first = getpass.getpass("新密码（输入时不显示）：")
    second = getpass.getpass("再输入一次：")
    if first != second:
        print("两次输入不一致，已取消。")
        return None
    try:
        validate_new_password(first, username)
    except AuthRuleError as e:
        print(f"密码不符合规则：{e.detail}，已取消。")
        return None
    return first


async def _run(args) -> int:
    url = _target_url(args.target)
    engine = make_engine(url, poolclass=NullPool)  # 内含 3306 防护
    print(f"目标数据库：{_describe(url)}")
    try:
        async with async_sessionmaker(engine, expire_on_commit=False)() as session:
            service = AuthService(session)

            if args.command == "list-users":
                users = (await session.scalars(select(User).order_by(User.id))).all()
                print(f"{'id':>5}  {'username':<20} {'active':<6} {'created_at':<25} last_login_at")
                for u in users:
                    print(f"{u.id:>5}  {u.username:<20} {str(u.is_active):<6} {_fmt(u.created_at):<25} "
                          f"{_fmt(u.last_login_at)}")
                print(f"共 {len(users)} 个用户")
                return 0

            if args.command == "cleanup-sessions":
                count = await service.count_expired_sessions()
                if args.dry_run:
                    print(f"[dry-run] 将删除 {count} 个过期或已撤销超过 7 天的会话")
                    return 0
                removed = await service.cleanup_sessions()
                print(f"已删除 {removed} 个会话")
                return 0

            if args.command == "cleanup-rate-limits":
                count = await limiter.count_expired(session)
                if args.dry_run:
                    print(f"[dry-run] 将删除 {count} 条超过 2 天的限流计数")
                    return 0
                removed = await limiter.cleanup(session)
                print(f"已删除 {removed} 条限流计数")
                return 0

            name = normalize_login_username(args.username)
            user = await session.scalar(select(User).where(User.username == name)) if name else None
            if user is None:
                print(f"用户 {args.username!r} 不存在。")
                return 1
            print(f"用户：id={user.id} username={user.username} active={user.is_active} "
                  f"last_login_at={_fmt(user.last_login_at)}")

            if args.command == "reset-password":
                if not _confirm(user.username, "重置密码并让该用户所有登录失效"):
                    return 1
                password = _read_new_password(user.username)
                if password is None:
                    return 1
                await service.admin_reset_password(user, password)
                print("密码已重置，该用户所有登录已失效。")
            elif args.command in ("disable", "enable"):
                active = args.command == "enable"
                if user.is_active == active:
                    print("状态未变化，无需操作。")
                    return 0
                action = "启用账号" if active else "停用账号并让该用户所有登录失效"
                if not _confirm(user.username, action):
                    return 1
                await service.admin_set_active(user, active)
                print("已启用。" if active else "已停用，该用户所有登录已失效。")
            return 0
    finally:
        await engine.dispose()


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(prog="python -m scripts.admin", description="账号管理（管理员）")
    parser.add_argument("--target", choices=["dev", "test"], default="dev", help="目标库，默认开发库")
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("list-users", help="列出用户（只读）")
    for name, help_ in [("reset-password", "重置密码"), ("disable", "停用账号"), ("enable", "启用账号")]:
        sub.add_parser(name, help=help_).add_argument("username")
    cleanup = sub.add_parser("cleanup-sessions", help="清理过期或已撤销超过 7 天的会话")
    cleanup.add_argument("--dry-run", action="store_true")
    rl_cleanup = sub.add_parser("cleanup-rate-limits", help="清理超过 2 天的限流计数")
    rl_cleanup.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    try:
        return asyncio.run(_run(args))
    except DatabaseConfigError as e:
        print(f"拒绝执行：{e}")
        return 2


if __name__ == "__main__":
    sys.exit(main())
