-- 베스트맘 만족도 조사 전용 새 Supabase 프로젝트에만 실행하세요.
-- 기존 제공기록지 Supabase 프로젝트에서는 절대 실행하지 마세요.
-- 관리자 계정은 Supabase Authentication > Users에서 확인된 이메일로 만드세요.
create table if not exists public.bestmom_responses (
  id bigint generated always as identity primary key,
  created_at timestamptz not null default now(),
  service_year integer not null check (service_year between 2024 and 2100),
  service_month integer not null check (service_month between 1 and 12),
  city text not null check (city in ('성남시','용인시')),
  source text not null,
  source_other text not null default '',
  comment text not null default '',
  answers jsonb not null,
  client_token uuid not null unique
);
create index if not exists bestmom_responses_filter_idx on public.bestmom_responses (service_year,service_month,city);
alter table public.bestmom_responses enable row level security;
revoke all on public.bestmom_responses from anon,authenticated;
grant select on public.bestmom_responses to authenticated;

-- 새 프로젝트 소유자 관리자 이메일. 기존 시스템과 데이터는 공유하지 않습니다.
create or replace function public.bestmom_is_admin()
returns boolean language sql stable security definer set search_path=''
as $$
  select exists (
    select 1 from auth.users u
    where u.id = (select auth.uid())
    and lower(u.email) = 'bestmom353535@gmail.com'
    and u.email_confirmed_at is not null
  );
$$;
revoke all on function public.bestmom_is_admin() from public, anon;
grant execute on function public.bestmom_is_admin() to authenticated;
drop policy if exists bestmom_admin_read on public.bestmom_responses;
create policy bestmom_admin_read on public.bestmom_responses
for select to authenticated using ((select public.bestmom_is_admin()));

create or replace function public.submit_bestmom_survey(
 p_year int, p_month int, p_city text, p_source text,
 p_source_other text, p_comment text, p_answers jsonb,
 p_token uuid, p_website text default ''
)
returns jsonb language plpgsql security definer set search_path=public,pg_temp as $$
declare k text;
begin
  -- 트랩 필드가 채워지면 저장하지 않음
  if coalesce(p_website,'') <> '' then return jsonb_build_object('ok',true); end if;
  if p_year is null or p_month is null or
     p_year not between 2024 and 2100 or p_month not between 1 and 12 or
     make_date(p_year,p_month,1) > date_trunc('month',now() at time zone 'Asia/Seoul')::date
  then raise exception '이용 연월을 확인해 주세요.'; end if;
  if p_city is null or p_city not in ('성남시','용인시')
  then raise exception '서비스 지역을 선택해 주세요.'; end if;
  if p_source is null or p_source not in ('온라인 및 SNS','친척·이웃 소개','기존 이용자 소개','보건소·지자체 안내','기관 안내 및 홍보','기타')
  then raise exception '인지 경로를 선택해 주세요.'; end if;
  if p_source = '기타' and length(trim(coalesce(p_source_other,'')))=0
  then raise exception '기타 경로를 입력해 주세요.'; end if;
  if length(coalesce(p_source_other,''))>100 or length(coalesce(p_comment,''))>1000
  then raise exception '입력 가능한 글자 수를 초과했습니다.'; end if;
  if p_token is null or p_answers is null or jsonb_typeof(p_answers) <> 'object'
  then raise exception '설문 응답을 확인해 주세요.'; end if;
  foreach k in array ARRAY['booking','hygiene','food','newborn','overall','recommend','mother_health','baby_health','mother_recovery','baby_growth']
  loop
    if (p_answers->>k) is null or (p_answers->>k) not in ('1','2','3','4','5')
    then raise exception '필수 문항에 답변해 주세요.'; end if;
  end loop;
  if (p_answers->>'needs') not in ('0','1')
  then raise exception '요청사항 문항을 확인해 주세요.'; end if;
  if (p_answers->>'complaint') not in ('none','resolved','unresolved')
  then raise exception '불편사항 문항을 확인해 주세요.'; end if;
  insert into public.bestmom_responses
    (service_year,service_month,city,source,source_other,comment,answers,client_token)
  values
    (p_year,p_month,p_city,p_source,coalesce(p_source_other,''),coalesce(p_comment,''),p_answers,p_token)
  on conflict (client_token) do nothing;
  return jsonb_build_object('ok',true);
end;
$$;
revoke all on function public.submit_bestmom_survey(int,int,text,text,text,text,jsonb,uuid,text) from public;
grant execute on function public.submit_bestmom_survey(int,int,text,text,text,text,jsonb,uuid,text) to anon,authenticated;
