// GENERATED from the hosted schema, which now matches the repo
// migrations exactly. Regenerate after every hosted apply:
//   supabase gen types typescript --project-id sbjpiajjlufrhigmovnk
// (or the Supabase MCP generate_typescript_types tool). Never hand-edit.
export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.17"
  }
  public: {
    Tables: {
      assessments: {
        Row: {
          closes_at: string
          cohort_id: string
          created_at: string
          id: string
          input_id: string
          live_session_id: string | null
          mode: string
          opens_at: string
          phase: string
          question_ids: Json
        }
        Insert: {
          closes_at: string
          cohort_id: string
          created_at?: string
          id?: string
          input_id: string
          live_session_id?: string | null
          mode?: string
          opens_at: string
          phase: string
          question_ids: Json
        }
        Update: {
          closes_at?: string
          cohort_id?: string
          created_at?: string
          id?: string
          input_id?: string
          live_session_id?: string | null
          mode?: string
          opens_at?: string
          phase?: string
          question_ids?: Json
        }
        Relationships: [
          {
            foreignKeyName: "assessments_cohort_id_fkey"
            columns: ["cohort_id"]
            isOneToOne: false
            referencedRelation: "cohorts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "assessments_input_id_fkey"
            columns: ["input_id"]
            isOneToOne: false
            referencedRelation: "teaching_inputs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "assessments_live_session_id_fkey"
            columns: ["live_session_id"]
            isOneToOne: false
            referencedRelation: "live_sessions"
            referencedColumns: ["id"]
          },
        ]
      }
      card_states: {
        Row: {
          card_id: string
          difficulty: number | null
          due_at: string | null
          is_new: boolean
          lapses: number
          last_reviewed_at: string | null
          reps: number
          stability: number | null
          updated_at: string
          user_id: string
        }
        Insert: {
          card_id: string
          difficulty?: number | null
          due_at?: string | null
          is_new?: boolean
          lapses?: number
          last_reviewed_at?: string | null
          reps?: number
          stability?: number | null
          updated_at?: string
          user_id: string
        }
        Update: {
          card_id?: string
          difficulty?: number | null
          due_at?: string | null
          is_new?: boolean
          lapses?: number
          last_reviewed_at?: string | null
          reps?: number
          stability?: number | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "card_states_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      class_announcements: {
        Row: {
          author: string
          body: string
          cohort_id: string
          created_at: string
          id: string
          pushed_at: string | null
        }
        Insert: {
          author: string
          body: string
          cohort_id: string
          created_at?: string
          id?: string
          pushed_at?: string | null
        }
        Update: {
          author?: string
          body?: string
          cohort_id?: string
          created_at?: string
          id?: string
          pushed_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "class_announcements_author_fkey"
            columns: ["author"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "class_announcements_cohort_id_fkey"
            columns: ["cohort_id"]
            isOneToOne: false
            referencedRelation: "cohorts"
            referencedColumns: ["id"]
          },
        ]
      }
      cohort_members: {
        Row: {
          cohort_id: string
          joined_at: string
          role: string
          roster_name: string | null
          user_id: string
        }
        Insert: {
          cohort_id: string
          joined_at?: string
          role: string
          roster_name?: string | null
          user_id: string
        }
        Update: {
          cohort_id?: string
          joined_at?: string
          role?: string
          roster_name?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "cohort_members_cohort_id_fkey"
            columns: ["cohort_id"]
            isOneToOne: false
            referencedRelation: "cohorts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cohort_members_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      cohort_outcomes: {
        Row: {
          cohort_id: string
          first_attempt_pass_rate: number | null
          recorded_at: string
          source: string
        }
        Insert: {
          cohort_id: string
          first_attempt_pass_rate?: number | null
          recorded_at?: string
          source?: string
        }
        Update: {
          cohort_id?: string
          first_attempt_pass_rate?: number | null
          recorded_at?: string
          source?: string
        }
        Relationships: [
          {
            foreignKeyName: "cohort_outcomes_cohort_id_fkey"
            columns: ["cohort_id"]
            isOneToOne: true
            referencedRelation: "cohorts"
            referencedColumns: ["id"]
          },
        ]
      }
      cohort_rollups: {
        Row: {
          active_users: number | null
          baseline_avg: Json | null
          cohort_id: string
          computed_at: string
          engagement: Json | null
          final_avg: Json | null
          lift: Json | null
          questions_answered: number | null
          sessions: number | null
        }
        Insert: {
          active_users?: number | null
          baseline_avg?: Json | null
          cohort_id: string
          computed_at?: string
          engagement?: Json | null
          final_avg?: Json | null
          lift?: Json | null
          questions_answered?: number | null
          sessions?: number | null
        }
        Update: {
          active_users?: number | null
          baseline_avg?: Json | null
          cohort_id?: string
          computed_at?: string
          engagement?: Json | null
          final_avg?: Json | null
          lift?: Json | null
          questions_answered?: number | null
          sessions?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "cohort_rollups_cohort_id_fkey"
            columns: ["cohort_id"]
            isOneToOne: false
            referencedRelation: "cohorts"
            referencedColumns: ["id"]
          },
        ]
      }
      cohorts: {
        Row: {
          created_at: string
          created_by: string
          exam_window: unknown
          id: string
          identity_display: string
          is_demo: boolean
          join_code: string
          name: string
          org_id: string | null
          raw_retention_days: number | null
          reporting_resolution: string
          term: string | null
        }
        Insert: {
          created_at?: string
          created_by: string
          exam_window?: unknown
          id?: string
          identity_display?: string
          is_demo?: boolean
          join_code?: string
          name: string
          org_id?: string | null
          raw_retention_days?: number | null
          reporting_resolution?: string
          term?: string | null
        }
        Update: {
          created_at?: string
          created_by?: string
          exam_window?: unknown
          id?: string
          identity_display?: string
          is_demo?: boolean
          join_code?: string
          name?: string
          org_id?: string | null
          raw_retention_days?: number | null
          reporting_resolution?: string
          term?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "cohorts_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "cohorts_org_id_fkey"
            columns: ["org_id"]
            isOneToOne: false
            referencedRelation: "orgs"
            referencedColumns: ["id"]
          },
        ]
      }
      content_versions: {
        Row: {
          git_sha: string | null
          id: string
          published_at: string
          version: string
        }
        Insert: {
          git_sha?: string | null
          id?: string
          published_at?: string
          version: string
        }
        Update: {
          git_sha?: string | null
          id?: string
          published_at?: string
          version?: string
        }
        Relationships: []
      }
      domains: {
        Row: {
          code: string
          id: number
          name: string
          ordinal: number
        }
        Insert: {
          code: string
          id: number
          name: string
          ordinal: number
        }
        Update: {
          code?: string
          id?: number
          name?: string
          ordinal?: number
        }
        Relationships: []
      }
      entities: {
        Row: {
          citations: Json
          content_version_id: string | null
          data: Json
          domain_id: number | null
          id: string
          name: string
          slug: string
          type: string
        }
        Insert: {
          citations?: Json
          content_version_id?: string | null
          data?: Json
          domain_id?: number | null
          id?: string
          name: string
          slug: string
          type: string
        }
        Update: {
          citations?: Json
          content_version_id?: string | null
          data?: Json
          domain_id?: number | null
          id?: string
          name?: string
          slug?: string
          type?: string
        }
        Relationships: [
          {
            foreignKeyName: "entities_content_version_id_fkey"
            columns: ["content_version_id"]
            isOneToOne: false
            referencedRelation: "content_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "entities_domain_id_fkey"
            columns: ["domain_id"]
            isOneToOne: false
            referencedRelation: "domains"
            referencedColumns: ["id"]
          },
        ]
      }
      entitlements: {
        Row: {
          capability: string
          expires_at: string | null
          granted_at: string
          source: string
          user_id: string
        }
        Insert: {
          capability: string
          expires_at?: string | null
          granted_at?: string
          source: string
          user_id: string
        }
        Update: {
          capability?: string
          expires_at?: string | null
          granted_at?: string
          source?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "entitlements_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      events: {
        Row: {
          assessment_id: string | null
          attempt_id: string | null
          chosen_key: string | null
          client_ts: string
          cohort_id: string | null
          correct: boolean | null
          device_id: string | null
          domain_id: number | null
          event_id: string
          payload: Json
          question_id: string | null
          server_ts: string
          type: string
          user_id: string
        }
        Insert: {
          assessment_id?: string | null
          attempt_id?: string | null
          chosen_key?: string | null
          client_ts: string
          cohort_id?: string | null
          correct?: boolean | null
          device_id?: string | null
          domain_id?: number | null
          event_id: string
          payload?: Json
          question_id?: string | null
          server_ts?: string
          type: string
          user_id: string
        }
        Update: {
          assessment_id?: string | null
          attempt_id?: string | null
          chosen_key?: string | null
          client_ts?: string
          cohort_id?: string | null
          correct?: boolean | null
          device_id?: string | null
          domain_id?: number | null
          event_id?: string
          payload?: Json
          question_id?: string | null
          server_ts?: string
          type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "events_assessment_id_fkey"
            columns: ["assessment_id"]
            isOneToOne: false
            referencedRelation: "assessments"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "events_attempt_id_fkey"
            columns: ["attempt_id"]
            isOneToOne: false
            referencedRelation: "mock_attempts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "events_cohort_id_fkey"
            columns: ["cohort_id"]
            isOneToOne: false
            referencedRelation: "cohorts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "events_domain_id_fkey"
            columns: ["domain_id"]
            isOneToOne: false
            referencedRelation: "domains"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "events_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "questions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "events_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      faculty_invites: {
        Row: {
          code: string
          created_at: string
          max_uses: number
          minted_by: string
          note: string | null
          uses: number
        }
        Insert: {
          code?: string
          created_at?: string
          max_uses?: number
          minted_by: string
          note?: string | null
          uses?: number
        }
        Update: {
          code?: string
          created_at?: string
          max_uses?: number
          minted_by?: string
          note?: string | null
          uses?: number
        }
        Relationships: [
          {
            foreignKeyName: "faculty_invites_minted_by_fkey"
            columns: ["minted_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      input_items: {
        Row: {
          input_id: string
          question_id: string
          slice: string
        }
        Insert: {
          input_id: string
          question_id: string
          slice: string
        }
        Update: {
          input_id?: string
          question_id?: string
          slice?: string
        }
        Relationships: [
          {
            foreignKeyName: "input_items_input_id_fkey"
            columns: ["input_id"]
            isOneToOne: false
            referencedRelation: "teaching_inputs"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "input_items_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "questions"
            referencedColumns: ["id"]
          },
        ]
      }
      item_states: {
        Row: {
          difficulty: number
          due_at: string
          lapses: number
          last_reviewed_at: string
          question_id: string
          reps: number
          stability: number
          user_id: string
        }
        Insert: {
          difficulty: number
          due_at: string
          lapses?: number
          last_reviewed_at: string
          question_id: string
          reps?: number
          stability: number
          user_id: string
        }
        Update: {
          difficulty?: number
          due_at?: string
          lapses?: number
          last_reviewed_at?: string
          question_id?: string
          reps?: number
          stability?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "item_states_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "questions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "item_states_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      leaderboard: {
        Row: {
          cohort_id: string
          score: number
          updated_at: string
          user_id: string
        }
        Insert: {
          cohort_id: string
          score?: number
          updated_at?: string
          user_id: string
        }
        Update: {
          cohort_id?: string
          score?: number
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "leaderboard_cohort_id_fkey"
            columns: ["cohort_id"]
            isOneToOne: false
            referencedRelation: "cohorts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "leaderboard_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      live_answers: {
        Row: {
          answer_ms: number
          chosen_key: string
          correct: boolean
          created_at: string
          folded: boolean
          question_id: string
          session_id: string
          user_id: string
        }
        Insert: {
          answer_ms: number
          chosen_key: string
          correct: boolean
          created_at?: string
          folded?: boolean
          question_id: string
          session_id: string
          user_id: string
        }
        Update: {
          answer_ms?: number
          chosen_key?: string
          correct?: boolean
          created_at?: string
          folded?: boolean
          question_id?: string
          session_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "live_answers_question_id_fkey"
            columns: ["question_id"]
            isOneToOne: false
            referencedRelation: "questions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "live_answers_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "live_sessions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "live_answers_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      live_participants: {
        Row: {
          display_name: string | null
          is_guest: boolean
          joined_at: string
          session_id: string
          user_id: string
        }
        Insert: {
          display_name?: string | null
          is_guest?: boolean
          joined_at?: string
          session_id: string
          user_id: string
        }
        Update: {
          display_name?: string | null
          is_guest?: boolean
          joined_at?: string
          session_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "live_participants_session_id_fkey"
            columns: ["session_id"]
            isOneToOne: false
            referencedRelation: "live_sessions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "live_participants_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      live_sessions: {
        Row: {
          allow_guests: boolean
          cohort_id: string
          created_at: string
          created_by: string
          current_index: number
          ended_at: string | null
          id: string
          input_id: string | null
          join_code: string
          question_ids: Json
          question_seconds: number
          question_started_at: string | null
          status: string
          title: string
        }
        Insert: {
          allow_guests?: boolean
          cohort_id: string
          created_at?: string
          created_by: string
          current_index?: number
          ended_at?: string | null
          id?: string
          input_id?: string | null
          join_code?: string
          question_ids: Json
          question_seconds?: number
          question_started_at?: string | null
          status?: string
          title: string
        }
        Update: {
          allow_guests?: boolean
          cohort_id?: string
          created_at?: string
          created_by?: string
          current_index?: number
          ended_at?: string | null
          id?: string
          input_id?: string | null
          join_code?: string
          question_ids?: Json
          question_seconds?: number
          question_started_at?: string | null
          status?: string
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "live_sessions_cohort_id_fkey"
            columns: ["cohort_id"]
            isOneToOne: false
            referencedRelation: "cohorts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "live_sessions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "live_sessions_input_id_fkey"
            columns: ["input_id"]
            isOneToOne: false
            referencedRelation: "teaching_inputs"
            referencedColumns: ["id"]
          },
        ]
      }
      mock_attempts: {
        Row: {
          cohort_id: string | null
          completed_at: string | null
          content_version_id: string | null
          id: string
          kind: string
          passed: boolean | null
          per_domain: Json | null
          question_ids: Json
          score: number | null
          started_at: string
          user_id: string
        }
        Insert: {
          cohort_id?: string | null
          completed_at?: string | null
          content_version_id?: string | null
          id?: string
          kind: string
          passed?: boolean | null
          per_domain?: Json | null
          question_ids: Json
          score?: number | null
          started_at?: string
          user_id: string
        }
        Update: {
          cohort_id?: string | null
          completed_at?: string | null
          content_version_id?: string | null
          id?: string
          kind?: string
          passed?: boolean | null
          per_domain?: Json | null
          question_ids?: Json
          score?: number | null
          started_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "mock_attempts_cohort_id_fkey"
            columns: ["cohort_id"]
            isOneToOne: false
            referencedRelation: "cohorts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "mock_attempts_content_version_id_fkey"
            columns: ["content_version_id"]
            isOneToOne: false
            referencedRelation: "content_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "mock_attempts_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      objectives: {
        Row: {
          code: string
          description: string
          domain_id: number
          id: string
        }
        Insert: {
          code: string
          description: string
          domain_id: number
          id?: string
        }
        Update: {
          code?: string
          description?: string
          domain_id?: number
          id?: string
        }
        Relationships: [
          {
            foreignKeyName: "objectives_domain_id_fkey"
            columns: ["domain_id"]
            isOneToOne: false
            referencedRelation: "domains"
            referencedColumns: ["id"]
          },
        ]
      }
      orgs: {
        Row: {
          id: string
          name: string
        }
        Insert: {
          id?: string
          name: string
        }
        Update: {
          id?: string
          name?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          avatar_id: number
          created_at: string
          handle: string
          id: string
          is_guest: boolean
          school: string | null
        }
        Insert: {
          avatar_id?: number
          created_at?: string
          handle: string
          id: string
          is_guest?: boolean
          school?: string | null
        }
        Update: {
          avatar_id?: number
          created_at?: string
          handle?: string
          id?: string
          is_guest?: boolean
          school?: string | null
        }
        Relationships: []
      }
      pulse_cache: {
        Row: {
          fetched_at: string
          key: string
          payload: Json
        }
        Insert: {
          fetched_at?: string
          key: string
          payload: Json
        }
        Update: {
          fetched_at?: string
          key?: string
          payload?: Json
        }
        Relationships: []
      }
      push_tokens: {
        Row: {
          environment: string
          platform: string
          token: string
          updated_at: string
          user_id: string
        }
        Insert: {
          environment?: string
          platform?: string
          token: string
          updated_at?: string
          user_id: string
        }
        Update: {
          environment?: string
          platform?: string
          token?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "push_tokens_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      questions: {
        Row: {
          author: string
          citation: string
          cohort_id: string | null
          content_version_id: string | null
          created_at: string
          created_by: string | null
          difficulty: number
          domain_id: number
          entity_id: string | null
          id: string
          objective_id: string | null
          options: Json
          review_status: string
          stem: string
        }
        Insert: {
          author?: string
          citation: string
          cohort_id?: string | null
          content_version_id?: string | null
          created_at?: string
          created_by?: string | null
          difficulty?: number
          domain_id: number
          entity_id?: string | null
          id?: string
          objective_id?: string | null
          options: Json
          review_status?: string
          stem: string
        }
        Update: {
          author?: string
          citation?: string
          cohort_id?: string | null
          content_version_id?: string | null
          created_at?: string
          created_by?: string | null
          difficulty?: number
          domain_id?: number
          entity_id?: string | null
          id?: string
          objective_id?: string | null
          options?: Json
          review_status?: string
          stem?: string
        }
        Relationships: [
          {
            foreignKeyName: "questions_cohort_id_fkey"
            columns: ["cohort_id"]
            isOneToOne: false
            referencedRelation: "cohorts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "questions_content_version_id_fkey"
            columns: ["content_version_id"]
            isOneToOne: false
            referencedRelation: "content_versions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "questions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "questions_domain_id_fkey"
            columns: ["domain_id"]
            isOneToOne: false
            referencedRelation: "domains"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "questions_entity_id_fkey"
            columns: ["entity_id"]
            isOneToOne: false
            referencedRelation: "entities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "questions_objective_id_fkey"
            columns: ["objective_id"]
            isOneToOne: false
            referencedRelation: "objectives"
            referencedColumns: ["id"]
          },
        ]
      }
      redemption_codes: {
        Row: {
          capability: string
          code: string
          cohort_id: string | null
          expires_at: string | null
          max_uses: number | null
          uses: number
        }
        Insert: {
          capability: string
          code: string
          cohort_id?: string | null
          expires_at?: string | null
          max_uses?: number | null
          uses?: number
        }
        Update: {
          capability?: string
          code?: string
          cohort_id?: string | null
          expires_at?: string | null
          max_uses?: number | null
          uses?: number
        }
        Relationships: [
          {
            foreignKeyName: "redemption_codes_cohort_id_fkey"
            columns: ["cohort_id"]
            isOneToOne: false
            referencedRelation: "cohorts"
            referencedColumns: ["id"]
          },
        ]
      }
      streaks: {
        Row: {
          current: number
          last_active_date: string | null
          longest: number
          user_id: string
        }
        Insert: {
          current?: number
          last_active_date?: string | null
          longest?: number
          user_id: string
        }
        Update: {
          current?: number
          last_active_date?: string | null
          longest?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "streaks_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      teaching_inputs: {
        Row: {
          cohort_id: string
          created_at: string
          created_by: string
          id: string
          kind: string
          taught_on: string
          title: string
        }
        Insert: {
          cohort_id: string
          created_at?: string
          created_by: string
          id?: string
          kind: string
          taught_on: string
          title: string
        }
        Update: {
          cohort_id?: string
          created_at?: string
          created_by?: string
          id?: string
          kind?: string
          taught_on?: string
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "teaching_inputs_cohort_id_fkey"
            columns: ["cohort_id"]
            isOneToOne: false
            referencedRelation: "cohorts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teaching_inputs_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      user_app_state: {
        Row: {
          chapter_number: number
          day_in_chapter: number
          deck_subscriptions: Json
          updated_at: string
          user_id: string
          xp: number
        }
        Insert: {
          chapter_number?: number
          day_in_chapter?: number
          deck_subscriptions?: Json
          updated_at?: string
          user_id: string
          xp?: number
        }
        Update: {
          chapter_number?: number
          day_in_chapter?: number
          deck_subscriptions?: Json
          updated_at?: string
          user_id?: string
          xp?: number
        }
        Relationships: [
          {
            foreignKeyName: "user_app_state_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      user_domain_readiness: {
        Row: {
          accuracy: number | null
          cohort_id: string | null
          domain_id: number
          readiness: number | null
          updated_at: string
          user_id: string
        }
        Insert: {
          accuracy?: number | null
          cohort_id?: string | null
          domain_id: number
          readiness?: number | null
          updated_at?: string
          user_id: string
        }
        Update: {
          accuracy?: number | null
          cohort_id?: string | null
          domain_id?: number
          readiness?: number | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_domain_readiness_cohort_id_fkey"
            columns: ["cohort_id"]
            isOneToOne: false
            referencedRelation: "cohorts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_domain_readiness_domain_id_fkey"
            columns: ["domain_id"]
            isOneToOne: false
            referencedRelation: "domains"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_domain_readiness_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      user_objective_readiness: {
        Row: {
          accuracy: number | null
          cohort_id: string | null
          objective_id: string
          readiness: number | null
          updated_at: string
          user_id: string
        }
        Insert: {
          accuracy?: number | null
          cohort_id?: string | null
          objective_id: string
          readiness?: number | null
          updated_at?: string
          user_id: string
        }
        Update: {
          accuracy?: number | null
          cohort_id?: string | null
          objective_id?: string
          readiness?: number | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_objective_readiness_cohort_id_fkey"
            columns: ["cohort_id"]
            isOneToOne: false
            referencedRelation: "cohorts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_objective_readiness_objective_id_fkey"
            columns: ["objective_id"]
            isOneToOne: false
            referencedRelation: "objectives"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_objective_readiness_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      active_live_session: { Args: { p_cohort: string }; Returns: Json }
      add_co_faculty: {
        Args: { p_cohort: string; p_email: string }
        Returns: undefined
      }
      add_cohort_ta: {
        Args: { p_cohort: string; p_email: string }
        Returns: undefined
      }
      admin_canary_status: { Args: never; Returns: Json }
      admin_list_cohorts: {
        Args: never
        Returns: {
          answers_7d: number
          cohort_id: string
          created_at: string
          creator_handle: string
          faculty: number
          join_code: string
          name: string
          students: number
          term: string
        }[]
      }
      admin_list_invites: {
        Args: never
        Returns: {
          code: string
          created_at: string
          max_uses: number
          minted_by_handle: string
          note: string
          uses: number
        }[]
      }
      admin_list_live_sessions: {
        Args: never
        Returns: {
          cohort_name: string
          created_at: string
          ended_at: string
          participants: number
          questions: number
          session_id: string
          status: string
          title: string
        }[]
      }
      admin_overview: { Args: never; Returns: Json }
      admin_search_users: {
        Args: { p_q: string }
        Returns: {
          classes: number
          created_at: string
          email: string
          handle: string
          is_admin: boolean
          is_faculty: boolean
          user_id: string
        }[]
      }
      admin_set_faculty: {
        Args: { p_user: string; p_verified: boolean }
        Returns: undefined
      }
      advance_live_session: { Args: { p_session: string }; Returns: Json }
      am_admin: { Args: never; Returns: boolean }
      am_verified_faculty: { Args: never; Returns: boolean }
      assemble_mock: { Args: { p_kind: string }; Returns: Json }
      at_risk_students: {
        Args: { p_cohort: string; p_threshold?: number }
        Returns: {
          answers_14d: number
          display_name: string
          last_active: string
          overall_readiness: number
          student_ref: string
          weakest_domain_id: number
          weakest_domain_name: string
          weakest_readiness: number
        }[]
      }
      capture_cohort_baseline: {
        Args: { p_cohort: string }
        Returns: undefined
      }
      cohort_distribution: { Args: { p_cohort: string }; Returns: Json }
      cohort_domain_stats: {
        Args: { p_cohort: string; p_min_n?: number }
        Returns: {
          accuracy: number
          answers: number
          domain_code: string
          domain_name: string
          students: number
        }[]
      }
      cohort_engagement_trend: {
        Args: { p_cohort: string; p_days?: number }
        Returns: {
          active_students: number
          answers: number
          day: string
        }[]
      }
      cohort_live_sessions: {
        Args: { p_cohort: string }
        Returns: {
          avg_correct: number
          created_at: string
          ended_at: string
          participants: number
          questions: number
          session_id: string
          status: string
          title: string
        }[]
      }
      cohort_overview: {
        Args: { p_cohort: string }
        Returns: {
          active_7d: number
          answers_total: number
          mocks_completed: number
          students: number
        }[]
      }
      cohort_pulse: { Args: { p_cohort: string }; Returns: Json }
      cohort_student_progress: {
        Args: { p_cohort: string }
        Returns: {
          accuracy: number
          answers_total: number
          best_mock_score: number
          handle: string
          last_active: string
          mocks_completed: number
          roster_name: string
          student_ref: string
          user_id: string
        }[]
      }
      cohort_top_misses: {
        Args: { p_cohort: string; p_limit?: number; p_min_n?: number }
        Returns: {
          attempts: number
          domain_code: string
          miss_rate: number
          question_id: string
          stem: string
          students: number
        }[]
      }
      create_cohort: {
        Args: { p_name: string; p_term?: string }
        Returns: Json
      }
      create_cohort_question: {
        Args: {
          p_answer_key: string
          p_citation?: string
          p_cohort: string
          p_domain: number
          p_explanation?: string
          p_options: Json
          p_stem: string
        }
        Returns: string
      }
      create_live_session: {
        Args: {
          p_cohort: string
          p_question_ids: Json
          p_question_seconds?: number
          p_title: string
        }
        Returns: Json
      }
      create_teaching_input: {
        Args: {
          p_cohort_id: string
          p_holdout_each?: number
          p_kind: string
          p_question_ids: string[]
          p_taught_on?: string
          p_title: string
        }
        Returns: Json
      }
      delete_my_account: { Args: never; Returns: undefined }
      end_live_session: { Args: { p_session: string }; Returns: undefined }
      enter_live_session: { Args: { p_session: string }; Returns: undefined }
      finalize_mock: { Args: { p_attempt_id: string }; Returns: Json }
      get_cohort_baseline: { Args: { p_cohort: string }; Returns: Json }
      get_live_question: { Args: { p_session: string }; Returns: Json }
      get_open_assessments: {
        Args: never
        Returns: {
          answered: number
          assessment_id: string
          closes_at: string
          input_title: string
          opens_at: string
          phase: string
          question_ids: Json
        }[]
      }
      get_reporting_policy: { Args: { p_cohort: string }; Returns: Json }
      join_cohort: {
        Args: { p_code: string; p_roster_name?: string }
        Returns: string
      }
      join_live_session: { Args: { p_code: string }; Returns: Json }
      join_live_session_guest: {
        Args: { p_code: string; p_display_name: string }
        Returns: Json
      }
      live_reveal: { Args: { p_session: string }; Returns: Json }
      live_scoreboard: {
        Args: { p_session: string }
        Returns: {
          correct_count: number
          handle: string
          is_me: boolean
          rank: number
          score: number
        }[]
      }
      live_session_report: {
        Args: { p_session: string }
        Returns: {
          answered: number
          correct_count: number
          handle: string
          per_question: Json
          roster_name: string
          score: number
          student_ref: string
          user_id: string
        }[]
      }
      live_session_stats: {
        Args: { p_session: string }
        Returns: {
          answered: number
          correct_rate: number
          question_id: string
          stem: string
        }[]
      }
      locked_question_ids: { Args: never; Returns: string[] }
      log_report_export: {
        Args: { p_cohort: string; p_kind: string }
        Returns: undefined
      }
      mint_faculty_invite: { Args: { p_note?: string }; Returns: string }
      my_cohort_role: { Args: { p_cohort: string }; Returns: string }
      my_faculty_overview: {
        Args: never
        Returns: {
          accuracy: number
          active_7d: number
          answers_total: number
          cohort_id: string
          live_sessions: number
          mocks_completed: number
          name: string
          students: number
          term: string
        }[]
      }
      my_roster_name: { Args: { p_cohort: string }; Returns: string }
      redeem_code: { Args: { p_code: string }; Returns: Json }
      redeem_faculty_invite: { Args: { p_code: string }; Returns: undefined }
      register_push_token: {
        Args: { p_environment?: string; p_token: string }
        Returns: undefined
      }
      remove_cohort_ta: {
        Args: { p_cohort: string; p_user: string }
        Returns: undefined
      }
      retire_cohort_question: {
        Args: { p_question: string }
        Returns: undefined
      }
      send_class_announcement: {
        Args: { p_body: string; p_cohort: string }
        Returns: Json
      }
      set_reporting_policy: {
        Args: {
          p_cohort: string
          p_identity_display: string
          p_resolution: string
          p_retention_days?: number
        }
        Returns: undefined
      }
      set_roster_name: {
        Args: { p_cohort: string; p_name: string }
        Returns: undefined
      }
      student_drilldown: {
        Args: { p_cohort: string; p_student_ref: string }
        Returns: Json
      }
      submit_answer: {
        Args: {
          p_assessment_id?: string
          p_attempt_id?: string
          p_chosen_key: string
          p_client_ts: string
          p_device_id?: string
          p_event_id: string
          p_question_id: string
        }
        Returns: Json
      }
      submit_live_answer: {
        Args: { p_key: string; p_question: string; p_session: string }
        Returns: Json
      }
      submit_review: {
        Args: {
          p_client_ts: string
          p_device_id?: string
          p_event_id: string
          p_grade: string
          p_question_id: string
        }
        Returns: Json
      }
      unregister_push_token: { Args: { p_token: string }; Returns: undefined }
      update_my_profile: {
        Args: { p_avatar_id?: number; p_handle?: string; p_school?: string }
        Returns: Json
      }
      upsert_faculty_question: {
        Args: {
          p_answer_key: string
          p_citation: string
          p_cohort_id: string
          p_difficulty?: number
          p_domain_code: string
          p_explanation: string
          p_objective_id?: string
          p_options: Json
          p_question_id: string
          p_review_status?: string
          p_stem: string
        }
        Returns: string
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const
