-- This migration runs ONLY on dedicated project bestmom-survey (xbwfwvmqxsrvtkgrqwpp).
-- Historical anonymous responses remain unchanged with NULL respondent_name / birth_date.
alter table public.bestmom_responses
  add column if not exists respondent_name text,
  add column if not exists birth_date date,
  add column if not exists identity_consent_at timestamptz;

create or replace function public.submit_bestmom_identified_survey(
  p_name text, p_birth_date date, p_city text, p_source text,
  p_source_other text, p_comment text, p_answers jsonb,
  p_token uuid, p_consent boolean, p_website text default ''
)
returns jsonb
language plpgsql security definer
set search_path=public,pg_temp
as $$
declare
  k text;
  submit_date date := (clock_timestamp() at time zone 'Asia/Seoul')::date;
begin
  -- Honeypot returns no-op to avoid distinguishing bots.
  if coalesce(p_website,'') <> '' then return jsonb_build_object('ok',true); end if;
  if p_consent is distinct from true then
    raise exception '개인정보 수집 및 이용에 동의해 주세요.';
  end if;
  if p_name is null or char_length(btrim(p_name)) not between 2 and 50
     or p_name ~ '[[:cntrl:]]' then
    raise exception '이름을 정확히 입력해 주세요.';
  end if;
  if p_birth_date is null or p_birth_date < date '1900-01-01' or p_birth_date > submit_date then
    raise exception '생년월일을 정확히 입력해 주세요.';
  end if;
  if p_city is null or p_city not in ('성남시','용인시') then
    raise exception '서비스 지역을 선택해 주세요.';
  end if;
  if p_source is null or p_source not in ('온라인 및 SNS','친척·이웃 소개','기존 이용자 소개','보건소·지자체 안내','기관 안내 및 홍보','기타') then
    raise exception '인지 경로를 선택해 주세요.';
  end if;
  if p_source = '기타' and length(trim(coalesce(p_source_other,''))) = 0 then
    raise exception '기타 경로를 입력해 주세요.';
  end if;
  if length(coalesce(p_source_other,'')) > 100 or length(coalesce(p_comment,'')) > 1000 then
    raise exception '입력 가능한 글자 수를 초과했습니다.';
  end if;
  if p_token is null or p_answers is null or jsonb_typeof(p_answers) <> 'object' then
    raise exception '설문 응답을 확인해 주세요.';
  end if;
  foreach k in array array['booking','hygiene','food','newborn','overall','recommend',
                           'mother_health','baby_health','mother_recovery','baby_growth']
  loop
    if coalesce(p_answers->>k,'') not in ('1','2','3','4','5') then
      raise exception '필수 문항에 답변해 주세요.';
    end if;
  end loop;
  if coalesce(p_answers->>'needs','') not in ('0','1') then
    raise exception '요청사항 문항을 확인해 주세요.';
  end if;
  if coalesce(p_answers->>'complaint','') not in ('none','resolved','unresolved') then
    raise exception '불편사항 문항을 확인해 주세요.';
  end if;

  insert into public.bestmom_responses
    (service_year,service_month,city,source,source_other,comment,answers,client_token,
     respondent_name,birth_date,identity_consent_at)
  values
    (extract(year from submit_date)::int,extract(month from submit_date)::int,
     p_city,p_source,coalesce(p_source_other,''),coalesce(p_comment,''),p_answers,p_token,
     btrim(p_name),p_birth_date,clock_timestamp())
  on conflict (client_token) do nothing;
  return jsonb_build_object('ok',true);
end;
$$;

revoke all on function public.submit_bestmom_identified_survey(text,date,text,text,text,text,jsonb,uuid,boolean,text) from public, anon, authenticated;
grant execute on function public.submit_bestmom_identified_survey(text,date,text,text,text,text,jsonb,uuid,boolean,text) to anon,authenticated;

-- Remove ONLY identifying details after 3 years; historical survey answers/statistics are retained.
select cron.schedule(
  'bestmom-survey-identity-minimization',
  '35 18 * * *',
  $$update public.bestmom_responses
      set respondent_name = null, birth_date = null
      where respondent_name is not null
        and created_at < (now() - interval '3 years');$$
);
