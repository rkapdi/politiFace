-- Version-control the push-washington poll schedule.
--
-- Until now the every-15-minutes pg_cron job invoking the push-washington
-- edge function existed only in the dashboard (and as a comment in the
-- function source), which means the repo could not prove the cadence and a
-- project restore would silently lose it. This migration owns the job.
--
-- Secret handling: the function requires an X-Cron-Secret header matching
-- its CRON_SECRET env. The value is NOT in this file; it is read at job
-- runtime from Vault (secret name 'cron_secret'). Setup, once, in SQL or
-- the dashboard:
--   select vault.create_secret('<the CRON_SECRET value>', 'cron_secret');
--
-- Safety: when pg_cron, pg_net, or the Vault secret are missing (local
-- test databases, or prod before the secret is created), this migration
-- logs a NOTICE and changes nothing, leaving any dashboard-configured job
-- untouched. Re-running after creating the secret adopts the job.

do $$
declare
  v_secret_exists boolean := false;
begin
  if not exists (select 1 from pg_extension where extname = 'pg_cron') then
    raise notice 'push-washington cron: pg_cron not installed; skipping';
    return;
  end if;
  if not exists (select 1 from pg_extension where extname = 'pg_net') then
    raise notice 'push-washington cron: pg_net not installed; skipping';
    return;
  end if;
  begin
    select exists (select 1 from vault.secrets where name = 'cron_secret')
      into v_secret_exists;
  exception when others then
    v_secret_exists := false;
  end;
  if not v_secret_exists then
    raise notice
      'push-washington cron: vault secret "cron_secret" not found; '
      'leaving existing schedule untouched';
    return;
  end if;

  if exists (select 1 from cron.job where jobname = 'push-washington-poll') then
    perform cron.unschedule('push-washington-poll');
  end if;

  perform cron.schedule(
    'push-washington-poll',
    '*/15 * * * *',
    $job$
    select net.http_post(
      url := 'https://sbjpiajjlufrhigmovnk.supabase.co/functions/v1/push-washington',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-Cron-Secret',
        (select decrypted_secret from vault.decrypted_secrets
          where name = 'cron_secret')
      ),
      body := '{}'::jsonb
    );
    $job$
  );
end $$;
