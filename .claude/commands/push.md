---
description: 원격 저장소에 코드를 푸시합니다. 푸시 전 최종 확인을 수행합니다.
---

# Git Push Workflow

## Step 1: 현재 브랜치 확인
```bash
git branch --show-current
```
// turbo

## Step 2: 원격 저장소 상태 확인
```bash
git fetch origin
git status
```
// turbo

## Step 3: 푸시할 커밋 확인
```bash
git log origin/$(git branch --show-current)..HEAD --oneline
```
// turbo

## Step 4: 충돌 가능성 체크
- 원격에 새 커밋이 있으면 사용자에게 알린다
- `git pull --rebase` 제안

## Step 5: 최종 확인
사용자에게 푸시할 내용을 요약하여 보여준다:

```markdown
## 푸시 예정 내용

- 브랜치: [branch_name]
- 커밋 수: N개
- 커밋 목록:
  - [hash1] message1
  - [hash2] message2

푸시를 진행할까요? (y/n)
```

## Step 6: 푸시 실행
사용자가 승인하면:
```bash
git push origin $(git branch --show-current)
```

## Step 7: 결과 보고
```markdown
## ✅ 푸시 완료

- 브랜치: [branch_name]
- 원격: origin
- 푸시된 커밋: N개

다음 단계: `/pr`로 Pull Request 생성
```
