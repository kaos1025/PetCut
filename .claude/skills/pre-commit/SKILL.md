---
name: pre-commit-check
description: 커밋 전 필수 검사를 수행합니다. 사용자가 "커밋 전 체크", "pre-commit", "커밋해도 되나", "푸시 전 확인" 등을 요청할 때 사용합니다.
---

# Pre-commit 체크 스킬

## 체크 순서

커밋/푸시 전에 아래 항목을 **순서대로** 확인하라:

### Step 1: 정적 분석 (필수)
```bash
flutter analyze
```
- ❌ Error가 1개라도 있으면 → **커밋 금지**
- ⚠️ Warning은 가능하면 수정

### Step 2: 포맷 정리
```bash
dart format .
```

### Step 3: 보안 체크 (필수)
아래 패턴이 코드에 있는지 검색:
```bash
grep -rnE "api[_-]?key|API[_-]?KEY|GEMINI_API_KEY|GOOGLE_API_KEY|ANTHROPIC_API_KEY|secret|password|token" lib/ --include="*.dart"
```
- ❌ 민감 정보 발견 시 → **커밋 금지**
- ✅ 정상: `dotenv.env['GEMINI_API_KEY']` 형태 (값이 아닌 키 이름 참조)

### Step 3.5: 가격 하드코딩 체크 (PetCut 필수)
```bash
grep -rnE "\\\$[0-9]+\\.[0-9]+|\\\$1\\.99|1\\.99 USD" lib/ --include="*.dart" || echo "✅ No hardcoded prices"
```
- ❌ 가격 하드코딩 발견 시 → **커밋 금지** (Play Billing `formattedPrice`만 사용)

### Step 4: 디버그 코드 체크
```bash
grep -rn "print(" lib/
```
- ⚠️ `print()` 문 발견 시 → 제거 권장

### Step 5: .env 파일 체크
```bash
git status | grep -E "\.env|\.secret|credentials"
```
- ❌ .env 파일이 staged 상태면 → **커밋 금지**

### Step 6: 테스트 실행 (선택)
```bash
flutter test
```
- ⚠️ 테스트 실패 시 → 확인 후 커밋

---

## 결과 출력 형식

체크 완료 후 아래 형식으로 보고하라:

```markdown
## Pre-commit 체크 결과

### 체크리스트
| 항목 | 상태 | 비고 |
|------|------|------|
| flutter analyze | ✅/❌ | Error N개 |
| dart format | ✅/❌ | 변경 N개 |
| 보안 체크 | ✅/❌ | 민감정보 발견 여부 |
| 가격 하드코딩 | ✅/❌ | $N.NN 발견 여부 |
| 디버그 코드 | ✅/⚠️ | print() N개 |
| .env 체크 | ✅/❌ | staged 여부 |
| 테스트 | ✅/⚠️/⏭️ | 통과/실패/스킵 |

### 🚨 블로커 (커밋 전 필수 수정)
- [있으면 나열]

### ⚠️ 권장 수정
- [있으면 나열]

### ✅ 최종 판정
**[커밋 가능 / 수정 필요]**
```

---

## 커밋 불가 조건 (Blocker)

아래 중 하나라도 해당하면 **절대 커밋 금지**:

1. `flutter analyze`에서 Error 발생
2. Gemini/Claude/Firebase API Key, 토큰, 비밀번호가 코드에 하드코딩
3. IAP 가격이 하드코딩 ($1.99 등) — Play Billing `formattedPrice`만 사용
4. `.env` 파일이 git staged 상태
5. 컴파일 에러 존재

---

## 커밋 가능 조건

아래 조건을 **모두** 만족해야 커밋 가능:

- [x] `flutter analyze` Error 0개
- [x] 민감 정보 하드코딩 없음
- [x] 가격 하드코딩 없음 (Play Billing `formattedPrice` 사용)
- [x] `.env` 파일 unstaged 상태
- [x] 코드 포맷 적용됨

---

## 커밋 메시지 제안

체크 통과 시 커밋 메시지도 함께 제안하라:

```markdown
### 제안 커밋 메시지

변경 내용을 분석한 결과:
- 주요 변경: [설명]
- 타입: feat/fix/refactor/docs/chore

**제안:**
```
feat: add pet profile screen for scan flow
```
```
