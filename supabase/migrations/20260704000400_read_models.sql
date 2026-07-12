-- Derived read models: recomputable from the event log at any time.
-- All writes happen inside the grading RPCs (same transaction as the event
-- insert); clients only read.

-- FSRS-4.5 state per user/question. Server-authoritative mirror of the same
-- algorithm the app runs locally (app/lib/features/session/domain/
-- fsrs_algorithm.dart); the weights below must stay identical to that file.
create table public.item_states (
  user_id          uuid not null references public.profiles (id) on delete cascade,
  question_id      uuid not null references public.questions (id) on delete cascade,
  stability        real not null,
  difficulty       real not null,
  due_at           timestamptz not null,
  last_reviewed_at timestamptz not null,
  reps             int not null default 0,
  lapses           int not null default 0,
  primary key (user_id, question_id)
);
create index item_states_due_idx on public.item_states (user_id, due_at);

create table public.user_domain_readiness (
  user_id    uuid not null references public.profiles (id) on delete cascade,
  cohort_id  uuid references public.cohorts (id),
  domain_id  smallint not null references public.domains (id),
  accuracy   real,             -- rolling accuracy over the last 50 answers
  readiness  real,             -- 0..1; v1: equals accuracy, refine later
  updated_at timestamptz not null default now(),
  primary key (user_id, domain_id)
);

-- Denormalized leaderboard. Score = total correct answers, incremented only
-- by the grading RPC, so it is server-authoritative by construction.
create table public.leaderboard (
  cohort_id  uuid not null references public.cohorts (id) on delete cascade,
  user_id    uuid not null references public.profiles (id) on delete cascade,
  score      integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (cohort_id, user_id)
);
create index leaderboard_rank_idx on public.leaderboard (cohort_id, score desc);

create table public.streaks (
  user_id          uuid primary key references public.profiles (id) on delete cascade,
  current          int not null default 0,
  longest          int not null default 0,
  last_active_date date
);

-- ── FSRS-4.5, ported 1:1 from the app's Dart implementation ─────────────────
-- Weights trained on 1.7B Anki reviews. Grade: 0 again, 1 hard, 2 good, 3 easy.
-- Requested retention 0.9, which makes interval = round(stability).
create function app.fsrs_schedule(
  p_stability   double precision,  -- null for a brand-new item
  p_difficulty  double precision,
  p_elapsed_days double precision,
  p_grade       int
) returns table (
  stability     double precision,
  difficulty    double precision,
  interval_days int
)
language plpgsql immutable as $$
declare
  w constant double precision[] := array[
    0.4072, 1.1829, 3.1262, 15.4722, 7.2102, 0.5316, 1.0651, 0.0589,
    1.5330, 0.1544, 0.9898, 1.9864, 0.1073, 0.3126, 2.2975, 0.2502, 2.9898];
  retention constant double precision := 0.9;
  r double precision;
  d double precision;
  s double precision;
begin
  if p_grade not between 0 and 3 then
    raise exception 'invalid FSRS grade %', p_grade;
  end if;

  if p_stability is null then
    -- First review: initial stability/difficulty from the grade alone.
    s := w[p_grade + 1];                                -- w[grade], 1-indexed
    d := w[5] - exp(w[6] * (p_grade - 1)) + 1;          -- w4 - e^(w5*(g-1)) + 1
  else
    -- Retrievability at review time (Ebbinghaus approximation).
    r := power(1.0 + p_elapsed_days / (9.0 * p_stability), -1);
    d := w[5] - exp(w[6] * (-w[7] * (p_grade - 3))) + (p_difficulty - w[5]) * 0.9;
    d := least(greatest(d, 1.0), 10.0);
    if p_grade = 0 then
      s := w[12] * power(d, -w[13]) * (power(p_stability + 1.0, w[14]) - 1.0)
           * exp((1.0 - r) * w[15]);
    else
      s := p_stability * (
        exp(w[9]) * (11.0 - d) * power(p_stability, -w[10])
        * (exp((1.0 - r) * w[11]) - 1.0)
        * (case when p_grade = 1 then w[16] else 1.0 end)   -- hard penalty
        * (case when p_grade = 3 then w[17] else 1.0 end)   -- easy bonus
        + 1.0);
    end if;
  end if;

  d := least(greatest(d, 1.0), 10.0);
  s := least(greatest(s, 0.1), 36500.0);

  return query select
    s, d, greatest(1, round(9.0 * s * (1.0 / retention - 1.0))::int);
end;
$$;

-- Apply one graded answer/review to every read model. Called by the grading
-- RPCs inside the same transaction as the event insert.
create function app.apply_graded_event(
  p_user     uuid,
  p_cohort   uuid,
  p_question uuid,
  p_domain   smallint,
  p_grade    int,          -- FSRS grade; answers map correct->2 (good), wrong->0 (again)
  p_correct  boolean,      -- null for pure FSRS reviews
  p_when     timestamptz
) returns void
language plpgsql as $$
declare
  st public.item_states%rowtype;
  f record;
  elapsed double precision;
  acc real;
begin
  -- FSRS state.
  select * into st from public.item_states
    where user_id = p_user and question_id = p_question;
  if found then
    elapsed := greatest(0.0,
      extract(epoch from (p_when - st.last_reviewed_at)) / 86400.0);
    select * into f from app.fsrs_schedule(st.stability, st.difficulty, elapsed, p_grade);
    update public.item_states set
      stability        = f.stability,
      difficulty       = f.difficulty,
      due_at           = p_when + make_interval(days => f.interval_days),
      last_reviewed_at = p_when,
      reps             = st.reps + 1,
      lapses           = st.lapses + (p_grade = 0)::int
    where user_id = p_user and question_id = p_question;
  else
    select * into f from app.fsrs_schedule(null, null, 0, p_grade);
    insert into public.item_states
      (user_id, question_id, stability, difficulty, due_at, last_reviewed_at,
       reps, lapses)
    values
      (p_user, p_question, f.stability, f.difficulty,
       p_when + make_interval(days => f.interval_days), p_when,
       1, (p_grade = 0)::int);
  end if;

  -- Streak (calendar day from the client's clock; lenient by design).
  insert into public.streaks (user_id, current, longest, last_active_date)
  values (p_user, 1, 1, p_when::date)
  on conflict (user_id) do update set
    current = case
      when public.streaks.last_active_date = excluded.last_active_date
        then public.streaks.current
      when public.streaks.last_active_date = excluded.last_active_date - 1
        then public.streaks.current + 1
      else 1
    end,
    longest = greatest(public.streaks.longest, case
      when public.streaks.last_active_date = excluded.last_active_date
        then public.streaks.current
      when public.streaks.last_active_date = excluded.last_active_date - 1
        then public.streaks.current + 1
      else 1
    end),
    last_active_date = excluded.last_active_date;

  if p_correct is not null then
    -- Leaderboard: +1 per correct answer.
    if p_cohort is not null and p_correct then
      insert into public.leaderboard (cohort_id, user_id, score, updated_at)
      values (p_cohort, p_user, 1, now())
      on conflict (cohort_id, user_id) do update set
        score = public.leaderboard.score + 1, updated_at = now();
    end if;

    -- Domain readiness: rolling accuracy over the last 50 graded answers.
    if p_domain is not null then
      select avg(correct::int)::real into acc from (
        select correct from public.events
        where user_id = p_user and domain_id = p_domain
          and type = 'answer' and correct is not null
        order by server_ts desc limit 50
      ) recent;
      insert into public.user_domain_readiness
        (user_id, cohort_id, domain_id, accuracy, readiness, updated_at)
      values (p_user, p_cohort, p_domain, acc, acc, now())
      on conflict (user_id, domain_id) do update set
        cohort_id = excluded.cohort_id,
        accuracy = excluded.accuracy,
        readiness = excluded.readiness,
        updated_at = now();
    end if;
  end if;
end;
$$;

-- ── RLS ─────────────────────────────────────────────────────────────────────
alter table public.item_states           enable row level security;
alter table public.user_domain_readiness enable row level security;
alter table public.leaderboard           enable row level security;
alter table public.streaks               enable row level security;

grant select on public.item_states, public.user_domain_readiness,
                public.leaderboard, public.streaks to authenticated;

create policy item_states_select_own on public.item_states for select
  to authenticated using (user_id = auth.uid());
create policy readiness_select_own on public.user_domain_readiness for select
  to authenticated using (user_id = auth.uid());
create policy streaks_select_own on public.streaks for select
  to authenticated using (user_id = auth.uid());

-- Cohort members see their cohort's leaderboard (pseudonymous handles join
-- via profiles RLS).
create policy leaderboard_select_cohort on public.leaderboard for select
  to authenticated using (app.is_cohort_member(cohort_id));
