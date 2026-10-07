#!/bin/bash
# MySQL 容器首次初始化（数据卷为空）时执行一次：建开发库、测试库与应用账号。
# 密码全部来自环境变量（docker/.env），不写死在这里。
# 官方入口脚本可能以 source 方式执行本脚本，只用与入口脚本一致的 -eo pipefail，不加 -u
set -eo pipefail

: "${MYSQL_ROOT_PASSWORD:?MYSQL_ROOT_PASSWORD 未设置（docker/.env）}"
: "${MYSQL_APP_USER:?MYSQL_APP_USER 未设置}"
: "${MYSQL_APP_PASSWORD:?MYSQL_APP_PASSWORD 未设置（docker/.env）}"

MYSQL_PWD="$MYSQL_ROOT_PASSWORD" mysql -uroot --protocol=socket <<-EOSQL
	CREATE DATABASE IF NOT EXISTS english_learning
	  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
	CREATE DATABASE IF NOT EXISTS english_learning_test
	  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
	CREATE USER IF NOT EXISTS '${MYSQL_APP_USER}'@'%' IDENTIFIED BY '${MYSQL_APP_PASSWORD}';
	GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP, REFERENCES
	  ON english_learning.* TO '${MYSQL_APP_USER}'@'%';
	GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, DROP, REFERENCES
	  ON english_learning_test.* TO '${MYSQL_APP_USER}'@'%';
EOSQL

echo "[init] databases english_learning / english_learning_test and user ${MYSQL_APP_USER} ready"
