---
name: flutter-analyze
description: Flutter 코드 품질을 분석합니다. 사용자가 "분석", "analyze", "lint", "품질 체크", "코드 검사" 등을 요청할 때 사용합니다.
---

# Flutter Analyze 스킬

## 실행 명령어

### 기본 분석
```bash
flutter analyze
```

### 특정 디렉토리만
```bash
flutter analyze lib/services/
```

### 자동 수정 가능한 것 확인
```bash
dart fix --dry-run
```

### 자동 수정 적용
```bash
dart fix --apply
```

### 포맷 체크
```bash
dart format --set-exit-if-changed .
```

### 포맷 적용
```bash
dart format .
```

---

## 분석 순서

아래 순서대로 실행하고 결과를 보고하라:

### Step 1: 정적 분석
```bash
flutter analyze
```

### Step 2: 포맷 체크
```bash
dart format --set-exit-if-changed .
```

### Step 3: 자동 수정 가능 항목 확인
```bash
dart fix --dry-run
```

---

## 분석 결과 해석

### Error (🚨 필수 수정)
- 컴파일 에러
- Null safety 위반
- 타입 에러

### Warning (⚠️ 권장 수정)
- 사용하지 않는 import
- 사용하지 않는 변수
- Deprecated API 사용

### Info (📝 참고)
- 코드 스타일 제안
- 최적화 힌트

---

## 결과 출력 형식

분석 완료 후 아래 형식으로 보고하라:

```markdown
## Flutter Analyze 결과

### 📊 요약
| 유형 | 개수 |
|------|------|
| 🚨 Error | N개 |
| ⚠️ Warning | N개 |
| 📝 Info | N개 |

### 🚨 Errors (수정 필수)
```
파일:라인:컬럼 - 에러 메시지
```

**수정 방법:**
```dart
// 수정된 코드
```

### ⚠️ Warnings (권장 수정)
- `파일:라인` - 경고 내용

### 🔧 자동 수정 가능
다음 명령어로 N개 이슈 자동 수정 가능:
```bash
dart fix --apply
```

### ✅ 최종 판정
- [ ] Error 0개 확인
- [ ] 포맷 적용됨
- [ ] 커밋 가능 상태
```

---

## PetCut 전용 추가 체크

아래 규칙은 `flutter analyze`로 잡히지 않으므로 수동으로 `grep`하여 보고하라:

### dynamic 금지
```bash
grep -rn "dynamic " lib/ --include="*.dart" | grep -v "//" || echo "✅ No dynamic usage"
```

### ! 연산자 남발
```bash
grep -rn "!\." lib/ --include="*.dart" | head -50
```
→ 각 사용처가 정당화되는지 검토 (대안: `?? defaultValue`, null 체크)

### 하드코딩 가격 / API key
```bash
grep -rnE "\\\$[0-9]+\\.[0-9]+|\\\$1\\.99|api[_-]?key|GOOGLE_API_KEY|GEMINI_API_KEY|ANTHROPIC" lib/ --include="*.dart" || echo "✅ Clean"
```

---

## 일반적인 이슈와 해결책

### 1. unused_import
```dart
// ❌ 사용하지 않는 import
import 'package:flutter/material.dart';
import 'package:unused_package/unused.dart'; // 삭제

// ✅ 필요한 것만
import 'package:flutter/material.dart';
```

### 2. prefer_const_constructors
```dart
// ❌ const 미사용
child: Text('Hello')

// ✅ const 사용
child: const Text('Hello')
```

### 3. avoid_print
```dart
// ❌ print 사용
print('debug: $value');

// ✅ 디버그 로그 사용 또는 제거
debugPrint('debug: $value'); // 또는 삭제
```

### 4. unnecessary_null_assertion
```dart
// ❌ 불필요한 !
final value = maybeNull!;

// ✅ null 체크
final value = maybeNull ?? defaultValue;
// 또는
if (maybeNull != null) {
  final value = maybeNull;
}
```
