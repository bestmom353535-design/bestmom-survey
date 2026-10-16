# 베스트맘 산후관리 만족도 조사

**독립 프로젝트:** 기존 제공기록지 작성 시스템 및 데이터베이스와 별개로 구축합니다.

## 구성
- `index.html` : 산모용 모바일 익명 설문 (단일 고정 링크)
- `admin.html` : 관리자 전용 월·연도·지역별 통계 및 CSV 다운로드
- `config.js` : 공개 Supabase URL 및 anon(publishable) key
- `supabase/schema.sql` : 새로운 설문 전용 Supabase 프로젝트의 비공개 응답 테이블과 접근 권한
- `.github/workflows/pages.yml` : GitHub Pages 배포

## 배포 전 반드시 수행할 사항
1. 이 저장소의 **Settings → Pages → Build and deployment → Source: GitHub Actions** 로 변경하세요.
2. 새 설문 전용 Supabase 프로젝트를 생성하세요. 기존 제공기록지 Supabase DB에서 SQL을 실행하지 마세요.
3. 새 프로젝트 SQL Editor에서 `supabase/schema.sql` 실행.
4. Authentication → Users에서 인증된 관리자 이메일 계정 생성 및 비밀번호 설정. 관리자 이메일은 SQL에서 지정한 계정과 일치해야 합니다.
5. 새 Supabase 프로젝트의 URL과 **공개 anon/publishable key만** `config.js`에 입력해 커밋하세요. **service_role/secret 키는 절대로 공개 GitHub에 입력하지 마세요.**
6. GitHub Pages의 실제 주소로 이동해 실제 테스트 설문을 제출하고, 전용 Supabase Table 저장 확인 → 로그인하지 않은 사용자 열람 차단 확인 → 관리자 로그인 및 CSV 다운로드 확인.

**현재 연결 전 상태에서는 제출 시 '설문 시스템 준비 중입니다' 메시지가 나타납니다. 산모님들에게 URL을 공유하지 마세요.**

## 보안 및 백업
- GitHub에는 설문 응답을 저장하지 않습니다. 별도 Supabase DB에만 저장합니다.
- RLS: 테이블 직접 조회는 관리자에게만 허용. 익명 사용자는 제출 전용 RPC만 호출 가능.
- 이름·전화번호 입력란 없음. 스팸이나 의도적인 중복 응답을 완전히 막는 것은 아닙니다.
- 자동 외부 백업은 **아직 미설정**입니다. 완성 전까지 관리자 화면 CSV 다운로드 후 별도의 보안 저장소에 정기 보관하세요.
- 무료 서비스 한도와 프로젝트 비활성화·복구 정책은 실제 계정 정책을 확인하세요.

## 기존 보고서와 연결된 지표
서비스 만족도 8개 핵심 항목 및 전체 만족도·의견, 산모 및 신생아 건강증진 4문항. 긍정적인 5점 선택지를 왼쪽에 배치하며, 식사·돌봄 문항에도 '해당 서비스 이용하지 않음' 선택지를 두지 않습니다.
