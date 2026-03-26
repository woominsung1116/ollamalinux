# OllamaLinux - Claude Code 규칙

## 필수 검증 프로세스

코드를 수정할 때마다 **반드시** 아래 두 에이전트에게 검증받고, 통과된 후에만 커밋/다음 작업 진행:

1. **아키텍트 에이전트** (`oh-my-claudecode:architect`, model=opus) - 구조/설계 검증
2. **검증 에이전트** (`oh-my-claudecode:verifier`, model=opus) - 구현 정확성 검증

둘 다 APPROVED/ALL CLEAR가 나와야 커밋 가능. FAIL이면 수정 후 재검증.

## 에이전트 모델

- 모든 에이전트는 **항상 opus** 모델 사용. sonnet 사용 금지.

## 빌드 설정 (변경 금지)

- `--mode debian` 필수 (제거하면 Ubuntu 테마 에러)
- `--bootloader syslinux` + 로컬 bootloaders/isolinux 템플릿
- `--binary-images iso-hybrid`
- genisoimage `-allow-limited-size` 패치 필요 (4GB+ squashfs)
- Server/Desktop 빌드에 동일한 패치 적용할 것

## 스크립트 관리

- `scripts/`가 Single Source of Truth
- `includes.chroot/usr/local/bin/`의 스크립트는 .gitignore됨
- 빌드 시 CI가 scripts/ → includes.chroot/로 복사

## 보안 규칙

- curl|sh 패턴 금지 → 직접 바이너리 다운로드 + SHA256 검증
- 모든 서비스 localhost 바인딩 (0.0.0.0 금지)
- 모든 systemd 서비스에 NoNewPrivileges=true
- 설정 파일 읽기: source 금지 → grep/get_conf_value 사용
