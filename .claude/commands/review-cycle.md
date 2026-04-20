---
description: 개발 완료 전 전체 품질 체크 사이클을 실행합니다. 분석 → 테스트 → 리뷰 → 커밋 준비까지 한 번에 수행합니다.
---

# Review Cycle Workflow

> 이 워크플로우는 PR/Merge 전 필수 체크를 모두 수행합니다.

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

## Step 3: 분석 결과 판정
**Blocker 체크:**
- [ ] `flutter analyze` Error 0개

Error가 있으면 **즉시 중단**하고 수정 방법을 안내한다.

## Step 4: 테스트 실행
```bash
flutter test
```
// turbo

## Step 5: 테스트 결과 판정
**Blocker 체크:**
- [ ] 모든 테스트 통과

실패한 테스트가 있으면 목록과 수정 제안을 보여준다.

## Step 6: 보안 체크
```bash
grep -rnE "api[_-]?key|API[_-]?KEY|GEMINI_API_KEY|GOOGLE_API_KEY|ANTHROPIC_API_KEY|secret|password|token" lib/ --include="*.dart" || echo "✅ No sensitive data found"
```
// turbo

## Step 6.5: 가격 하드코딩 체크 (PetCut 필수)
```bash
grep -rnE "\\\$[0-9]+\\.[0-9]+|\\\$1\\.99" lib/ --include="*.dart" || echo "✅ No hardcoded prices"
```
// turbo

## Step 7: 디버그 코드 체크
```bash
grep -rn "print(" lib/ --include="*.dart" || echo "✅ No print statements"
```
// turbo

## Step 8: .env 파일 체크
```bash
git status | grep -E "\.env" && echo "❌ WARNING: .env file in staging!" || echo "✅ No .env in staging"
```
// turbo

## Step 9: 전체 결과 리포트

```markdown
## 📊 Review Cycle 결과

### 체크리스트
| 항목 | 상태 | 비고 |
|------|------|------|
| dart format | ✅/❌ | |
| flutter analyze | ✅/❌ | Error N개 |
| flutter test | ✅/❌ | 통과 N/N |
| 보안 체크 | ✅/❌ | |
| 가격 하드코딩 | ✅/❌ | $N.NN 발견 여부 |
| 디버그 코드 | ✅/⚠️ | print() N개 |
| .env 체크 | ✅/❌ | |

### 🚨 Blockers (있는 경우)
- [나열]

### ⚠️ Warnings (있는 경우)
- [나열]

### ✅ 최종 판정
**[통과 / 조건부 통과 / 실패]**
```

## Step 10: 다음 단계 안내

### 통과 시
```markdown
✅ 모든 체크 통과!

다음 단계:
1. `/commit` - 커밋 생성
2. `/push` - 원격 저장소에 푸시
3. `/pr` - PR 설명 생성
```

### 실패 시
```markdown
❌ 아래 항목을 수정 후 다시 `/review-cycle` 실행:

1. [수정 필요 항목]
2. [수정 필요 항목]
```
