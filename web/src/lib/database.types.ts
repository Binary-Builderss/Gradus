export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: { extensions?: Json; operationName?: string; query?: string; variables?: Json }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      block_weeks: {
        Row: {
          block_id: string
          created_at: string
          deleted_at: string | null
          id: string
          intensity_value: number | null
          mesocycle_id: string
          method: Database['public']['Enums']['intensity_method'] | null
          ref_pct: number | null
          reps_max: number | null
          reps_min: number | null
          sets: number
          updated_at: string
          week: number
        }
        ComputedFields: never
        Insert: {
          block_id: string
          created_at?: string
          deleted_at?: string | null
          id?: string
          intensity_value?: number | null
          mesocycle_id: string
          method?: Database['public']['Enums']['intensity_method'] | null
          ref_pct?: number | null
          reps_max?: number | null
          reps_min?: number | null
          sets: number
          updated_at?: string
          week: number
        }
        Update: {
          block_id?: string
          created_at?: string
          deleted_at?: string | null
          id?: string
          intensity_value?: number | null
          mesocycle_id?: string
          method?: Database['public']['Enums']['intensity_method'] | null
          ref_pct?: number | null
          reps_max?: number | null
          reps_min?: number | null
          sets?: number
          updated_at?: string
          week?: number
        }
        Relationships: [
          {
            foreignKeyName: 'block_weeks_block_id_mesocycle_id_fkey'
            columns: ['block_id', 'mesocycle_id']
            isOneToOne: false
            referencedRelation: 'set_blocks'
            referencedColumns: ['id', 'mesocycle_id']
          },
        ]
      }
      coach_athletes: {
        Row: {
          athlete_id: string
          coach_id: string
          created_at: string
          id: string
          status: Database['public']['Enums']['link_status']
          updated_at: string
        }
        ComputedFields: never
        Insert: {
          athlete_id: string
          coach_id: string
          created_at?: string
          id?: string
          status?: Database['public']['Enums']['link_status']
          updated_at?: string
        }
        Update: {
          athlete_id?: string
          coach_id?: string
          created_at?: string
          id?: string
          status?: Database['public']['Enums']['link_status']
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: 'coach_athletes_athlete_id_fkey'
            columns: ['athlete_id']
            isOneToOne: false
            referencedRelation: 'profiles'
            referencedColumns: ['id']
          },
          {
            foreignKeyName: 'coach_athletes_coach_id_fkey'
            columns: ['coach_id']
            isOneToOne: false
            referencedRelation: 'profiles'
            referencedColumns: ['id']
          },
        ]
      }
      coach_branding: {
        Row: {
          brand_name: string | null
          coach_id: string
          colors: NonNullable<Json>
          created_at: string
          logo_png: string | null
          updated_at: string
        }
        ComputedFields: never
        Insert: {
          brand_name?: string | null
          coach_id: string
          colors?: NonNullable<Json>
          created_at?: string
          logo_png?: string | null
          updated_at?: string
        }
        Update: {
          brand_name?: string | null
          coach_id?: string
          colors?: NonNullable<Json>
          created_at?: string
          logo_png?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: 'coach_branding_coach_id_fkey'
            columns: ['coach_id']
            isOneToOne: true
            referencedRelation: 'profiles'
            referencedColumns: ['id']
          },
        ]
      }
      coach_plans: {
        Row: {
          billing_ref: string | null
          cancel_at_period_end: boolean
          coach_id: string
          created_at: string
          plan: Database['public']['Enums']['coach_plan']
          pro_until: string | null
          updated_at: string
        }
        ComputedFields: never
        Insert: {
          billing_ref?: string | null
          cancel_at_period_end?: boolean
          coach_id: string
          created_at?: string
          plan?: Database['public']['Enums']['coach_plan']
          pro_until?: string | null
          updated_at?: string
        }
        Update: {
          billing_ref?: string | null
          cancel_at_period_end?: boolean
          coach_id?: string
          created_at?: string
          plan?: Database['public']['Enums']['coach_plan']
          pro_until?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: 'coach_plans_coach_id_fkey'
            columns: ['coach_id']
            isOneToOne: true
            referencedRelation: 'profiles'
            referencedColumns: ['id']
          },
        ]
      }
      exercise_muscles: {
        Row: {
          created_at: string
          exercise_id: string
          id: string
          muscle: Database['public']['Enums']['muscle']
          updated_at: string
          weight: number
        }
        ComputedFields: never
        Insert: {
          created_at?: string
          exercise_id: string
          id?: string
          muscle: Database['public']['Enums']['muscle']
          updated_at?: string
          weight: number
        }
        Update: {
          created_at?: string
          exercise_id?: string
          id?: string
          muscle?: Database['public']['Enums']['muscle']
          updated_at?: string
          weight?: number
        }
        Relationships: [
          {
            foreignKeyName: 'exercise_muscles_exercise_id_fkey'
            columns: ['exercise_id']
            isOneToOne: false
            referencedRelation: 'exercises'
            referencedColumns: ['id']
          },
        ]
      }
      exercise_videos: {
        Row: {
          created_at: string
          exercise_id: string
          id: string
          owner_id: string
          title: string | null
          updated_at: string
          url: string
        }
        ComputedFields: never
        Insert: {
          created_at?: string
          exercise_id: string
          id?: string
          owner_id: string
          title?: string | null
          updated_at?: string
          url: string
        }
        Update: {
          created_at?: string
          exercise_id?: string
          id?: string
          owner_id?: string
          title?: string | null
          updated_at?: string
          url?: string
        }
        Relationships: [
          {
            foreignKeyName: 'exercise_videos_exercise_id_fkey'
            columns: ['exercise_id']
            isOneToOne: false
            referencedRelation: 'exercises'
            referencedColumns: ['id']
          },
          {
            foreignKeyName: 'exercise_videos_owner_id_fkey'
            columns: ['owner_id']
            isOneToOne: false
            referencedRelation: 'profiles'
            referencedColumns: ['id']
          },
        ]
      }
      exercises: {
        Row: {
          created_at: string
          deleted_at: string | null
          id: string
          name: string
          notes: string | null
          owner_id: string | null
          updated_at: string
        }
        ComputedFields: never
        Insert: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          name: string
          notes?: string | null
          owner_id?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          name?: string
          notes?: string | null
          owner_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: 'exercises_owner_id_fkey'
            columns: ['owner_id']
            isOneToOne: false
            referencedRelation: 'profiles'
            referencedColumns: ['id']
          },
        ]
      }
      mesocycle_templates: {
        Row: {
          created_at: string
          description: string | null
          id: string
          name: string
          owner_id: string
          sessions: number
          structure: NonNullable<Json>
          updated_at: string
          weeks: number
        }
        ComputedFields: never
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          name: string
          owner_id: string
          sessions: number
          structure: NonNullable<Json>
          updated_at?: string
          weeks: number
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          name?: string
          owner_id?: string
          sessions?: number
          structure?: NonNullable<Json>
          updated_at?: string
          weeks?: number
        }
        Relationships: [
          {
            foreignKeyName: 'mesocycle_templates_owner_id_fkey'
            columns: ['owner_id']
            isOneToOne: false
            referencedRelation: 'profiles'
            referencedColumns: ['id']
          },
        ]
      }
      mesocycles: {
        Row: {
          athlete_id: string
          coach_notes: string | null
          created_at: string
          deload_weeks: number[]
          id: string
          name: string
          start_date: string
          status: Database['public']['Enums']['mesocycle_status']
          updated_at: string
          weeks: number
        }
        ComputedFields: never
        Insert: {
          athlete_id: string
          coach_notes?: string | null
          created_at?: string
          deload_weeks?: number[]
          id?: string
          name: string
          start_date: string
          status?: Database['public']['Enums']['mesocycle_status']
          updated_at?: string
          weeks: number
        }
        Update: {
          athlete_id?: string
          coach_notes?: string | null
          created_at?: string
          deload_weeks?: number[]
          id?: string
          name?: string
          start_date?: string
          status?: Database['public']['Enums']['mesocycle_status']
          updated_at?: string
          weeks?: number
        }
        Relationships: [
          {
            foreignKeyName: 'mesocycles_athlete_id_fkey'
            columns: ['athlete_id']
            isOneToOne: false
            referencedRelation: 'profiles'
            referencedColumns: ['id']
          },
        ]
      }
      profiles: {
        Row: {
          created_at: string
          disabled_at: string | null
          email: string | null
          full_name: string | null
          id: string
          updated_at: string
        }
        ComputedFields: never
        Insert: {
          created_at?: string
          disabled_at?: string | null
          email?: string | null
          full_name?: string | null
          id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          disabled_at?: string | null
          email?: string | null
          full_name?: string | null
          id?: string
          updated_at?: string
        }
        Relationships: []
      }
      progression_presets: {
        Row: {
          created_at: string
          id: string
          name: string
          owner_id: string
          rule: NonNullable<Json>
          updated_at: string
        }
        ComputedFields: never
        Insert: {
          created_at?: string
          id?: string
          name: string
          owner_id: string
          rule: NonNullable<Json>
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
          owner_id?: string
          rule?: NonNullable<Json>
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: 'progression_presets_owner_id_fkey'
            columns: ['owner_id']
            isOneToOne: false
            referencedRelation: 'profiles'
            referencedColumns: ['id']
          },
        ]
      }
      sessions: {
        Row: {
          coach_notes: string | null
          created_at: string
          deleted_at: string | null
          id: string
          mesocycle_id: string
          name: string
          position: number
          updated_at: string
        }
        ComputedFields: never
        Insert: {
          coach_notes?: string | null
          created_at?: string
          deleted_at?: string | null
          id?: string
          mesocycle_id: string
          name: string
          position: number
          updated_at?: string
        }
        Update: {
          coach_notes?: string | null
          created_at?: string
          deleted_at?: string | null
          id?: string
          mesocycle_id?: string
          name?: string
          position?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: 'sessions_mesocycle_id_fkey'
            columns: ['mesocycle_id']
            isOneToOne: false
            referencedRelation: 'mesocycles'
            referencedColumns: ['id']
          },
        ]
      }
      set_blocks: {
        Row: {
          created_at: string
          deleted_at: string | null
          id: string
          mesocycle_id: string
          position: number
          prep_s: number | null
          ref_block_id: string | null
          rest_s: number | null
          role: Database['public']['Enums']['block_role']
          slot_id: string
          technique: Database['public']['Enums']['technique']
          technique_params: NonNullable<Json>
          tut_bottom_pause_s: number | null
          tut_concentric_s: number | null
          tut_eccentric_s: number | null
          tut_top_pause_s: number | null
          updated_at: string
        }
        ComputedFields: never
        Insert: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          mesocycle_id: string
          position: number
          prep_s?: number | null
          ref_block_id?: string | null
          rest_s?: number | null
          role?: Database['public']['Enums']['block_role']
          slot_id: string
          technique?: Database['public']['Enums']['technique']
          technique_params?: NonNullable<Json>
          tut_bottom_pause_s?: number | null
          tut_concentric_s?: number | null
          tut_eccentric_s?: number | null
          tut_top_pause_s?: number | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          mesocycle_id?: string
          position?: number
          prep_s?: number | null
          ref_block_id?: string | null
          rest_s?: number | null
          role?: Database['public']['Enums']['block_role']
          slot_id?: string
          technique?: Database['public']['Enums']['technique']
          technique_params?: NonNullable<Json>
          tut_bottom_pause_s?: number | null
          tut_concentric_s?: number | null
          tut_eccentric_s?: number | null
          tut_top_pause_s?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: 'set_blocks_ref_block_id_mesocycle_id_fkey'
            columns: ['ref_block_id', 'mesocycle_id']
            isOneToOne: false
            referencedRelation: 'set_blocks'
            referencedColumns: ['id', 'mesocycle_id']
          },
          {
            foreignKeyName: 'set_blocks_slot_id_mesocycle_id_fkey'
            columns: ['slot_id', 'mesocycle_id']
            isOneToOne: false
            referencedRelation: 'slots'
            referencedColumns: ['id', 'mesocycle_id']
          },
        ]
      }
      set_logs: {
        Row: {
          athlete_id: string
          block_id: string
          created_at: string
          deleted_at: string | null
          done_at: string
          effort_scale: Database['public']['Enums']['effort_scale'] | null
          effort_value: number | null
          id: string
          mesocycle_id: string
          set_idx: number
          updated_at: string
          workout_id: string
        }
        ComputedFields: never
        Insert: {
          athlete_id: string
          block_id: string
          created_at?: string
          deleted_at?: string | null
          done_at?: string
          effort_scale?: Database['public']['Enums']['effort_scale'] | null
          effort_value?: number | null
          id?: string
          mesocycle_id: string
          set_idx: number
          updated_at?: string
          workout_id: string
        }
        Update: {
          athlete_id?: string
          block_id?: string
          created_at?: string
          deleted_at?: string | null
          done_at?: string
          effort_scale?: Database['public']['Enums']['effort_scale'] | null
          effort_value?: number | null
          id?: string
          mesocycle_id?: string
          set_idx?: number
          updated_at?: string
          workout_id?: string
        }
        Relationships: [
          {
            foreignKeyName: 'set_logs_block_id_mesocycle_id_fkey'
            columns: ['block_id', 'mesocycle_id']
            isOneToOne: false
            referencedRelation: 'set_blocks'
            referencedColumns: ['id', 'mesocycle_id']
          },
          {
            foreignKeyName: 'set_logs_workout_id_athlete_id_mesocycle_id_fkey'
            columns: ['workout_id', 'athlete_id', 'mesocycle_id']
            isOneToOne: false
            referencedRelation: 'workouts'
            referencedColumns: ['id', 'athlete_id', 'mesocycle_id']
          },
        ]
      }
      set_segments: {
        Row: {
          athlete_id: string
          created_at: string
          deleted_at: string | null
          id: string
          load_kg: number | null
          reps: number | null
          seg_idx: number
          set_log_id: string
          updated_at: string
        }
        ComputedFields: never
        Insert: {
          athlete_id: string
          created_at?: string
          deleted_at?: string | null
          id?: string
          load_kg?: number | null
          reps?: number | null
          seg_idx: number
          set_log_id: string
          updated_at?: string
        }
        Update: {
          athlete_id?: string
          created_at?: string
          deleted_at?: string | null
          id?: string
          load_kg?: number | null
          reps?: number | null
          seg_idx?: number
          set_log_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: 'set_segments_set_log_id_athlete_id_fkey'
            columns: ['set_log_id', 'athlete_id']
            isOneToOne: false
            referencedRelation: 'set_logs'
            referencedColumns: ['id', 'athlete_id']
          },
        ]
      }
      slot_groups: {
        Row: {
          created_at: string
          deleted_at: string | null
          id: string
          kind: Database['public']['Enums']['group_kind']
          mesocycle_id: string
          position: number
          rest_after_round_s: number
          rest_between_s: number
          session_id: string
          updated_at: string
        }
        ComputedFields: never
        Insert: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          kind?: Database['public']['Enums']['group_kind']
          mesocycle_id: string
          position: number
          rest_after_round_s?: number
          rest_between_s?: number
          session_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          kind?: Database['public']['Enums']['group_kind']
          mesocycle_id?: string
          position?: number
          rest_after_round_s?: number
          rest_between_s?: number
          session_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: 'slot_groups_session_id_mesocycle_id_fkey'
            columns: ['session_id', 'mesocycle_id']
            isOneToOne: false
            referencedRelation: 'sessions'
            referencedColumns: ['id', 'mesocycle_id']
          },
        ]
      }
      slots: {
        Row: {
          coach_notes: string | null
          created_at: string
          deleted_at: string | null
          exercise_id: string
          group_id: string
          id: string
          mesocycle_id: string
          position: number
          updated_at: string
        }
        ComputedFields: never
        Insert: {
          coach_notes?: string | null
          created_at?: string
          deleted_at?: string | null
          exercise_id: string
          group_id: string
          id?: string
          mesocycle_id: string
          position: number
          updated_at?: string
        }
        Update: {
          coach_notes?: string | null
          created_at?: string
          deleted_at?: string | null
          exercise_id?: string
          group_id?: string
          id?: string
          mesocycle_id?: string
          position?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: 'slots_exercise_id_fkey'
            columns: ['exercise_id']
            isOneToOne: false
            referencedRelation: 'exercises'
            referencedColumns: ['id']
          },
          {
            foreignKeyName: 'slots_group_id_mesocycle_id_fkey'
            columns: ['group_id', 'mesocycle_id']
            isOneToOne: false
            referencedRelation: 'slot_groups'
            referencedColumns: ['id', 'mesocycle_id']
          },
        ]
      }
      workouts: {
        Row: {
          athlete_id: string
          athlete_notes: string | null
          created_at: string
          deleted_at: string | null
          id: string
          mesocycle_id: string
          session_id: string
          updated_at: string
          week: number
        }
        ComputedFields: never
        Insert: {
          athlete_id: string
          athlete_notes?: string | null
          created_at?: string
          deleted_at?: string | null
          id?: string
          mesocycle_id: string
          session_id: string
          updated_at?: string
          week: number
        }
        Update: {
          athlete_id?: string
          athlete_notes?: string | null
          created_at?: string
          deleted_at?: string | null
          id?: string
          mesocycle_id?: string
          session_id?: string
          updated_at?: string
          week?: number
        }
        Relationships: [
          {
            foreignKeyName: 'workouts_mesocycle_id_athlete_id_fkey'
            columns: ['mesocycle_id', 'athlete_id']
            isOneToOne: false
            referencedRelation: 'mesocycles'
            referencedColumns: ['id', 'athlete_id']
          },
          {
            foreignKeyName: 'workouts_session_id_mesocycle_id_fkey'
            columns: ['session_id', 'mesocycle_id']
            isOneToOne: false
            referencedRelation: 'sessions'
            referencedColumns: ['id', 'mesocycle_id']
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      athlete_best_sets: {
        Args: { p_athlete_id: string }
        Returns: {
          best_e1rm: number
          best_load_kg: number
          best_on: string
          best_reps: number
          exercise_id: string
          exercise_name: string
          last_on: string
          workouts: number
        }[]
      }
      clone_mesocycle: {
        Args: { p_mesocycle_id: string; p_name?: string; p_start_date: string }
        Returns: string
      }
      generate_progression: { Args: { p_block_id: string; p_rule: Json }; Returns: number }
      has_pro_plan: { Args: Record<PropertyKey, never>; Returns: boolean }
      instantiate_template: {
        Args: { p_athlete_id: string; p_name?: string; p_start_date: string; p_template_id: string }
        Returns: string
      }
      plan_limits: {
        Args: Record<PropertyKey, never>
        Returns: {
          athlete_limit: number
          plan: Database['public']['Enums']['coach_plan']
        }[]
      }
      plan_usage: {
        Args: Record<PropertyKey, never>
        Returns: {
          athlete_limit: number
          athletes: number
          can_customize: boolean
          cancel_at_period_end: boolean
          has_subscription: boolean
          plan: Database['public']['Enums']['coach_plan']
          renews_until: string
        }[]
      }
      prepare_account_deletion: { Args: { p_user_id: string }; Returns: undefined }
      preview_progression: {
        Args: { p_block_id: string; p_rule: Json }
        Returns: {
          action: string
          intensity_value: number
          method: Database['public']['Enums']['intensity_method']
          reps_max: number
          reps_min: number
          sets: number
          week: number
        }[]
      }
      previous_week_reference: {
        Args: { p_session_id: string; p_week: number }
        Returns: {
          block_id: string
          effort_scale: Database['public']['Enums']['effort_scale']
          effort_value: number
          ref_week: number
          segments: Json
          set_idx: number
        }[]
      }
      save_mesocycle_as_template: {
        Args: { p_description?: string; p_mesocycle_id: string; p_name: string }
        Returns: string
      }
      top_set_history: {
        Args: { p_athlete_id: string; p_exercise_id: string }
        Returns: {
          e1rm: number
          load_kg: number
          mesocycle_id: string
          mesocycle_name: string
          performed_on: string
          reps: number
          week: number
          workout_id: string
        }[]
      }
      weekly_exercise_progress: {
        Args: { p_mesocycle_id: string }
        Returns: {
          e1rm: number
          exercise_id: string
          exercise_name: string
          sets_done: number
          sets_prescribed: number
          top_load_kg: number
          top_reps: number
          week: number
        }[]
      }
      weekly_muscle_volume: {
        Args: { p_mesocycle_id: string }
        Returns: {
          executed: number
          muscle: Database['public']['Enums']['muscle']
          prescribed: number
          week: number
        }[]
      }
    }
    Enums: {
      block_role: 'warmup' | 'top' | 'backoff' | 'working'
      coach_plan: 'free' | 'mid' | 'pro' | 'unlimited'
      effort_scale: 'BUF' | 'RPE'
      group_kind: 'single' | 'superset' | 'giant' | 'circuit' | 'jumpset'
      intensity_method: 'BUF' | 'RPE' | 'RM' | 'PCT_1RM' | 'LOAD'
      link_status: 'pending' | 'active' | 'ended'
      mesocycle_status: 'draft' | 'active' | 'completed'
      muscle:
        | 'chest'
        | 'lats'
        | 'upper_back'
        | 'traps'
        | 'front_delts'
        | 'side_delts'
        | 'rear_delts'
        | 'biceps'
        | 'triceps'
        | 'forearms'
        | 'abs'
        | 'lower_back'
        | 'glutes'
        | 'quads'
        | 'hamstrings'
        | 'adductors'
        | 'abductors'
        | 'calves'
      technique: 'none' | 'drop' | 'rest_pause' | 'myo' | 'cluster'
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, 'public'>]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    keyof (DefaultSchema['Tables'] & DefaultSchema['Views']) | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Views'])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Views'])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema['Tables'] & DefaultSchema['Views'])
    ? (DefaultSchema['Tables'] & DefaultSchema['Views'])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    keyof DefaultSchema['Tables'] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables']
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema['Tables']
    ? DefaultSchema['Tables'][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    keyof DefaultSchema['Tables'] | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables']
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions['schema']]['Tables'][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema['Tables']
    ? DefaultSchema['Tables'][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    keyof DefaultSchema['Enums'] | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions['schema']]['Enums']
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions['schema']]['Enums'][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema['Enums']
    ? DefaultSchema['Enums'][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    keyof DefaultSchema['CompositeTypes'] | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions['schema']]['CompositeTypes']
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions['schema']]['CompositeTypes'][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema['CompositeTypes']
    ? DefaultSchema['CompositeTypes'][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      block_role: ['warmup', 'top', 'backoff', 'working'],
      coach_plan: ['free', 'mid', 'pro', 'unlimited'],
      effort_scale: ['BUF', 'RPE'],
      group_kind: ['single', 'superset', 'giant', 'circuit', 'jumpset'],
      intensity_method: ['BUF', 'RPE', 'RM', 'PCT_1RM', 'LOAD'],
      link_status: ['pending', 'active', 'ended'],
      mesocycle_status: ['draft', 'active', 'completed'],
      muscle: [
        'chest',
        'lats',
        'upper_back',
        'traps',
        'front_delts',
        'side_delts',
        'rear_delts',
        'biceps',
        'triceps',
        'forearms',
        'abs',
        'lower_back',
        'glutes',
        'quads',
        'hamstrings',
        'adductors',
        'abductors',
        'calves',
      ],
      technique: ['none', 'drop', 'rest_pause', 'myo', 'cluster'],
    },
  },
} as const
