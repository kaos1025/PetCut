---
description: 코드 품질 체크 후 Git 커밋을 수행합니다. 분석, 포맷, 보안 체크를 자동으로 실행하고 커밋 메시지를 제안합니다.
---

# Git Commit Workflow

## Step 1: 포맷 정리
```bash
dart format .
```
// turbo

## Step 2: 정적 분석
```bash
flutter analyze
```
// turbo

## Step 3: 분석 결과 확인
- Error가 1개라도 있으면 **즉시 중단**하고 사용자에게 알린다
- Warning은 목록으로 보여주고 계속 진행

## Step 4: 보안 체크
```bash
grep -rnE "api[_-]?key|API[_-]?KEY|GEMINI_API_KEY|GOOGLE_API_KEY|ANTHROPIC_API_KEY|secret|password|token" lib/ --include="*.dart" || echo "No sensitive data found"
```
// turbo

## Step 4.5: 가격 하드코딩 체크 (PetCut 필수)
```bash
grep -rnE "\\\$[0-9]+\\.[0-9]+|\\\$1\\.99" lib/ --include="*.dart" || echo "No hardcoded prices"
```
// turbo
- ❌ 가격 하드코딩 발견 시 → **즉시 중단** (Play Billing `formattedPrice`만 사용)

## Step 5: 보안 결과 확인
- 민감 정보가 발견되면 **즉시 중단**
- `.env` 파일이 staged 상태인지 확인:
```bash
git status | grep -E "\.env" || echo "No .env in staging"
```
// turbo

## Step 6: 변경 사항 확인
```bash
git status
git diff --stat
```
// turbo

## Step 7: 커밋 메시지 제안
변경된 파일들을 분석하여 Conventional Commits 형식으로 메시지를 제안한다:

```
<type>: <subject>

Types:
- feat: 새 기능
- fix: 버그 수정
- refactor: 구조 개선
- docs: 문서
- chore: 설정/빌드
```

**사용자에게 제안 메시지를 보여주고 확인을 받는다.**

## Step 8: 커밋 실행
사용자가 승인하면:
```bash
git add .
git commit -m "<승인된 메시지>"
```

## Step 9: 결과 보고
```markdown
## ✅ 커밋 완료

- 커밋 해시: [hash]
- 메시지: [message]
- 변경 파일: N개

다음 단계: `/push`로 원격 저장소에 푸시
```
