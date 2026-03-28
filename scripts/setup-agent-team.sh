#!/bin/bash
# setup-agent-team.sh
#
# NanoClaw에 agent-works 마운트를 등록하는 스크립트.
# NanoClaw가 시작되고 Slack 채널이 registered_groups에 등록된 후 실행한다.
#
# 사용법:
#   ./scripts/setup-agent-team.sh
#
# 사전 조건:
#   1. NanoClaw 실행 중 또는 최소 1회 실행하여 DB 초기화 완료
#   2. Slack 채널 2개가 registered_groups에 등록되어 있어야 함
#      (메인 봇에게 채널 활성화 요청 후 실행)

DB_PATH="$(dirname "$0")/../data/nanoclaw.db"
AGENT_WORKS_PATH="$HOME/Documents/DevelopWorks/agent-works"

if [ ! -f "$DB_PATH" ]; then
  echo "❌ DB 파일을 찾을 수 없습니다: $DB_PATH"
  echo "   NanoClaw를 먼저 실행하세요."
  exit 1
fi

# registered_groups 테이블 존재 여부 확인
TABLE_EXISTS=$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='registered_groups';" 2>/dev/null)
if [ -z "$TABLE_EXISTS" ]; then
  echo "❌ registered_groups 테이블이 없습니다. NanoClaw를 먼저 실행하세요."
  exit 1
fi

echo "=== 등록된 그룹 목록 ==="
sqlite3 "$DB_PATH" "SELECT jid, name, folder FROM registered_groups;" 2>/dev/null
echo ""

# additionalMounts JSON
AGENT_MOUNT=$(cat <<EOF
{"additionalMounts":[{"hostPath":"$AGENT_WORKS_PATH","readonly":true}]}
EOF
)

# 트리거 이름 (Slack에서 @멘션할 이름)
PRODUCT_TRIGGER="director"
ADMIN_TRIGGER="admin-director"

echo "=== agent-works 마운트 + 트리거 이름 설정 적용 ==="
echo "마운트 경로: $AGENT_WORKS_PATH"
echo "Product Director 트리거: @${PRODUCT_TRIGGER}"
echo "Admin Director 트리거:   @${ADMIN_TRIGGER}"
echo ""

# slack_main 그룹 업데이트 (product Director)
RESULT=$(sqlite3 "$DB_PATH" "UPDATE registered_groups SET container_config='$AGENT_MOUNT', trigger_pattern='$PRODUCT_TRIGGER' WHERE folder='slack_main'; SELECT changes();" 2>/dev/null)
if [ "$RESULT" = "1" ]; then
  echo "✅ slack_main — @${PRODUCT_TRIGGER} 트리거, agent-works 마운트 완료"
else
  echo "⚠️  slack_main 그룹이 없습니다. Slack에서 product 채널을 먼저 활성화하세요."
fi

# slack_admin 그룹 업데이트 (admin Director)
RESULT=$(sqlite3 "$DB_PATH" "UPDATE registered_groups SET container_config='$AGENT_MOUNT', trigger_pattern='$ADMIN_TRIGGER' WHERE folder='slack_admin'; SELECT changes();" 2>/dev/null)
if [ "$RESULT" = "1" ]; then
  echo "✅ slack_admin — @${ADMIN_TRIGGER} 트리거, agent-works 마운트 완료"
else
  echo "⚠️  slack_admin 그룹이 없습니다. Slack에서 admin 채널을 먼저 활성화하세요."
fi

echo ""
echo "=== 최종 상태 ==="
sqlite3 "$DB_PATH" "SELECT folder, name, container_config FROM registered_groups WHERE folder IN ('slack_main','slack_admin');" 2>/dev/null

echo ""
echo "완료. NanoClaw를 재시작하면 마운트 설정이 적용됩니다."
