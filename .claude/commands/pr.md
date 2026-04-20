---
description: Pull Request 설명을 자동으로 생성합니다. 변경 사항을 분석하여 What/Why/How 형식으로 작성합니다.
---

# PR Description Workflow

## Step 1: 변경 사항 분석
```bash
git diff main --stat
```
// turbo

## Step 2: 커밋 히스토리 확인
```bash
git log main..HEAD --oneline
```
// turbo

## Step 3: 변경된 파일 내용 분석
```bash
git diff main --name-only
```
// turbo

## Step 4: PR 설명 생성
아래 형식으로 PR 설명을 생성한다:

```markdown
## 📋 What (무엇을)
<!-- 이 PR이 무엇을 변경하는지 -->

- 변경사항 1
- 변경사항 2

## 🤔 Why (왜)
<!-- 왜 이 변경이 필요한지 -->

- 이유 1
- 이유 2

## 🛠️ How (어떻게)
<!-- 어떻게 구현했는지 -->

- 구현 방법 1
- 구현 방법 2

## 🧪 테스트 방법
<!-- 이 변경을 어떻게 테스트할 수 있는지 -->

1. `flutter run` 으로 앱 실행
2. 홈 → Pet Profile 생성 (dog/cat, 체중, 생애주기)
3. Scan Label → 사료 + 보충제 사진 촬영 또는 업로드
4. 분석 결과 화면에서 [특정 경고/충돌] 확인
5. Disclaimer ("Not a substitute for professional veterinary advice") 노출 확인

## 📸 스크린샷 (선택)
<!-- UI 변경이 있다면 스크린샷 첨부 -->

## ✅ 체크리스트

- [ ] `flutter analyze` Error 0개
- [ ] 테스트 통과
- [ ] 코드 리뷰 완료
- [ ] 문서 업데이트 (필요시)
```

## Step 5: 사용자 확인
생성된 PR 설명을 보여주고 수정이 필요한지 확인한다.

## Step 6: 클립보드 복사 안내
```markdown
## ✅ PR 설명 생성 완료

위 내용을 복사하여 GitHub/GitLab PR 페이지에 붙여넣으세요.

### GitHub PR 생성 링크
https://github.com/kaos1025/PetCut/compare/main...[현재브랜치]
```
