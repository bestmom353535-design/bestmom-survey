# 베스트맘 산후관리 만족도 조사

기존 제공기록지 작성 시스템과 완전히 분리된 독립 프로젝트입니다.

## 운영 중인 사이트

- 산모용 익명 설문: https://bestmom353535-design.github.io/bestmom-survey/
- 관리자 전용 페이지: https://bestmom353535-design.github.io/bestmom-survey/admin.html
- GitHub Pages: GitHub Actions 자동 배포
- Supabase: 새 `bestmom-survey` 전용 프로젝트 (`xbwfwvmqxsrvtkgrqwpp`, Seoul)
- 관리자 로그인: Supabase Authentication 사용자 계정

## 파일

- `index.html`: 모바일 산모용 익명 설문
- `admin.html`: 관리자 전용 통계, 필터, CSV 및 JSON 백업 다운로드
- `config.js`: 별도 Supabase 프로젝트의 공개 API 연결 정보 (비밀키 아님)
- `supabase/schema.sql`: 익명 응답 저장 및 관리자 RLS
- `supabase/functions/bestmom-survey-backup/index.ts`: 비공개 Storage 백업·관리자 다운로드 서버 기능
- `supabase/backup_schedule.sql`: 자동 백업 일정 (실제 Supabase Vault 비밀키와 별도 설정)
- `.github/workflows/pages.yml`: GitHub Pages 게시

## 자동 백업 — 2026년 10월 16일 설정 완료

- 매일 **오전 3:10 한국시간** (= UTC 18:10) `pg_cron` → `pg_net` → Supabase Edge Function 실행
- 응답 전체를 `bestmom-survey-backups` **비공개 Supabase Storage**에 JSON 저장
- 일별 백업: 최대 약 45일 보관
- 월별 백업: 매월 1일 직전 월의 응답 전체 스냅샷을 별도 저장, 최대 약 25개월 보관
- 예약 실행 작업명: `bestmom-survey-private-backup-daily`
- 스케줄러 인증 토큰은 Supabase Vault에만 생성·보관하며 공개 GitHub에 저장하지 않음
- 관리자 페이지에서 최신 백업 확인 및 인증 후 JSON 원본 다운로드 가능
- 수동으로 실행한 최초 백업 파일 생성 시험 성공 (HTTP 200, Storage 파일 생성 확인)

**중요한 백업 한계:** Storage 백업도 **같은 Supabase 프로젝트**에 속합니다. 프로젝트 자체의 삭제·비활성화 또는 계정 전체 사고에 대한 완전한 별도 백업은 아닙니다. 관리자 화면의 JSON/CSV를 정기적으로 PC 또는 별도의 안전한 저장소에 복사하세요. 무료 플랜에서 프로젝트가 일시 중지되면 예약 백업이 지연될 수 있습니다.

## 응답 보안

- 응답 데이터는 GitHub 공개 저장소에 저장하지 않음
- `public.bestmom_responses` RLS 활성화, 익명 데이터 조회 금지
- 익명 제출은 검증된 제출 전용 RPC만 허용
- 자동 백업 다운로드는 서버에서 Supabase 인증 토큰 및 관리자 이메일을 검사한 후에만 허용
- Storage 버킷 공개 접근 비활성화
- 개인정보(이름·연락처) 입력란 없음
- 의도적 중복·허위 응답을 100% 방지하지는 않으므로 운영 중 점검 필요

## 운영 중 주의

- 관리자가 로그인했을 때 새로고침을 누르면 응답 및 백업 상태 갱신
- 관리자에서 백업이 2일 이상 새로 생성되지 않으면 Supabase Cron / Edge Function 로그 확인 필요
- 공개 API 키는 웹 UI용이며, `service_role`·`sb_secret` 등의 관리자 비밀키를 GitHub에 올리지 말 것
- GitHub Actions 혹은 Supabase 프로젝트 접근 설정 변경 시 재검증
- 무료 플랜 사용량과 정책은 변동 가능하며 영구 무료·무손실을 보장하지 않음
