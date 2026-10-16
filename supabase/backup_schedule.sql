-- Already applied by ChatGPT to the dedicated bestmom-survey Supabase project.
-- Daily at 03:10 Korea Standard Time (=18:10 UTC).
-- Cron token remains encrypted at rest in the dedicated Supabase Vault.
select cron.schedule(
 'bestmom-survey-private-backup-daily',
 '10 18 * * *',
 $job$
   select net.http_post(
     url := 'https://xbwfwvmqxsrvtkgrqwpp.supabase.co/functions/v1/bestmom-survey-backup',
     body := '{}'::jsonb,
     headers := jsonb_build_object(
       'Content-Type', 'application/json',
       'x-bestmom-scheduler-token', (
         select decrypted_secret
         from vault.decrypted_secrets
         where name = 'bestmom_survey_backup_cron_token'
       )
     ),
     timeout_milliseconds := 30000
   );
 $job$
);
