-- Local development seed (supabase db reset). NOT production content.
-- Generates a placeholder question bank big enough to assemble a Mock FCLE
-- (20 per domain) so the app and RPCs can be exercised end to end.
-- Real content arrives via the YAML -> Postgres CI ingest under a
-- content_version.

insert into public.content_versions (version, git_sha)
values ('dev-seed', null);

do $$
declare
  d record; i int; qid uuid;
begin
  for d in select id, code from public.domains loop
    for i in 1..25 loop
      insert into public.questions (domain_id, stem, options, citation, review_status)
      values (d.id,
              format('[dev seed] %s placeholder question %s?', d.code, i),
              '[{"key":"a","text":"Option A"},{"key":"b","text":"Option B"},{"key":"c","text":"Option C"},{"key":"d","text":"Option D"}]',
              'https://constitution.congress.gov/',
              'draft')
      returning id into qid;
      insert into app.question_keys (question_id, answer_key, explanation)
      values (qid, 'b', 'Placeholder explanation for the dev seed.');
      update public.questions set review_status = 'published' where id = qid;
    end loop;
  end loop;
end $$;
