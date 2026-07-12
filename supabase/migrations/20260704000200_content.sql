-- Content: canonical from YAML in git, ingested by CI under a content_version.
-- Read-mostly. Everything cited. Answer keys and explanations live in the
-- protected app schema so PostgREST can never serve them to a client; the
-- grading RPC returns them after an answer is submitted.

create table public.content_versions (
  id           uuid primary key default gen_random_uuid(),
  version      text not null,
  git_sha      text,
  published_at timestamptz not null default now()
);

-- The four FCLE domains. Fixed vocabulary, seeded here.
create table public.domains (
  id      smallint primary key,
  code    text unique not null,
  name    text not null,
  ordinal smallint not null
);

insert into public.domains (id, code, name, ordinal) values
  (1, 'american_democracy',  'American Democracy',                          1),
  (2, 'us_constitution',     'United States Constitution',                  2),
  (3, 'founding_documents',  'Founding Documents',                          3),
  (4, 'landmark_impact',     'Landmark Influences and Supreme Court Cases', 4);

create table public.objectives (
  id          uuid primary key default gen_random_uuid(),
  domain_id   smallint not null references public.domains (id),
  code        text unique not null,
  description text not null
);
create index objectives_domain_idx on public.objectives (domain_id);

-- The Atlas graph. jsonb carries per-type fields (person, executive_order,
-- document, case, term, office). Every entity is cited.
create table public.entities (
  id                 uuid primary key default gen_random_uuid(),
  type               text not null,
  slug               text not null,
  name               text not null,
  domain_id          smallint references public.domains (id),
  data               jsonb not null default '{}',
  citations          jsonb not null default '[]',
  content_version_id uuid references public.content_versions (id),
  unique (type, slug)
);
create index entities_domain_idx on public.entities (domain_id);

-- Exam-prep MCQs. Client-visible columns only: no answer key, no explanation.
create table public.questions (
  id                 uuid primary key default gen_random_uuid(),
  domain_id          smallint not null references public.domains (id),
  objective_id       uuid references public.objectives (id),
  difficulty         smallint not null default 3 check (difficulty between 1 and 5),
  stem               text not null,
  options            jsonb not null,  -- [{key, text}, ...]
  citation           text not null check (length(trim(citation)) > 0),
  entity_id          uuid references public.entities (id),
  author             text not null default 'system' check (author in ('system', 'faculty')),
  review_status      text not null default 'draft'
                     check (review_status in ('draft', 'reviewed', 'published')),
  cohort_id          uuid references public.cohorts (id),  -- non-null = faculty-authored, cohort-scoped
  content_version_id uuid references public.content_versions (id),
  created_by         uuid references public.profiles (id), -- provenance for faculty questions
  created_at         timestamptz not null default now(),
  check (author <> 'faculty' or cohort_id is not null)
);
create index questions_domain_status_idx on public.questions (domain_id, review_status);
create index questions_cohort_idx on public.questions (cohort_id);
create index questions_objective_idx on public.questions (objective_id);

-- Server-only: graded by submit_answer, returned to the client only after an
-- answer is recorded. No client role has any privilege on schema app.
create table app.question_keys (
  question_id uuid primary key references public.questions (id) on delete cascade,
  answer_key  text not null,
  explanation text not null
);

-- A question cannot be published without its key.
create function app.check_question_publishable() returns trigger
language plpgsql as $$
begin
  if new.review_status = 'published'
     and not exists (select 1 from app.question_keys where question_id = new.id)
  then
    raise exception 'question % has no answer key; cannot publish', new.id;
  end if;
  return new;
end;
$$;

create trigger questions_publish_requires_key
  before insert or update of review_status on public.questions
  for each row when (new.review_status = 'published')
  execute function app.check_question_publishable();

-- ── RLS ─────────────────────────────────────────────────────────────────────
alter table public.content_versions enable row level security;
alter table public.domains          enable row level security;
alter table public.objectives       enable row level security;
alter table public.entities         enable row level security;
alter table public.questions        enable row level security;

grant select on public.content_versions, public.domains, public.objectives,
                public.entities to anon, authenticated;
grant select, insert, update on public.questions to authenticated;
grant select on public.questions to anon;

-- Reference content is world-readable (the app opens into value, no signup
-- wall; the YAML is public in the repo anyway).
create policy content_versions_select on public.content_versions for select using (true);
create policy domains_select          on public.domains          for select using (true);
create policy objectives_select       on public.objectives       for select using (true);
create policy entities_select         on public.entities         for select using (true);

-- System questions: published rows are world-readable. Cohort questions:
-- published rows for members; all statuses for that cohort's faculty.
create policy questions_select_published on public.questions for select
  using (cohort_id is null and review_status = 'published');
create policy questions_select_cohort on public.questions for select
  to authenticated using (
    cohort_id is not null
    and (
      (review_status = 'published' and app.is_cohort_member(cohort_id))
      or app.is_cohort_faculty(cohort_id)
    )
  );

-- Faculty author questions scoped to their own cohort. System content is
-- ingested by CI under the service role, which bypasses RLS.
create policy questions_insert_faculty on public.questions for insert
  to authenticated with check (
    author = 'faculty'
    and created_by = auth.uid()
    and cohort_id is not null
    and app.is_cohort_faculty(cohort_id)
  );
create policy questions_update_faculty on public.questions for update
  to authenticated using (
    author = 'faculty' and cohort_id is not null and app.is_cohort_faculty(cohort_id)
  )
  with check (
    author = 'faculty' and cohort_id is not null and app.is_cohort_faculty(cohort_id)
  );
