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
      exercises: {
        Row: {
          created_at: string
          deleted_at: string | null
          id: string
          name: string
          notes: string | null
          owner_id: string | null
          updated_at: string
          video_url: string | null
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
          video_url?: string | null
        }
        Update: {
          created_at?: string
          deleted_at?: string | null
          id?: string
          name?: string
          notes?: string | null
          owner_id?: string | null
          updated_at?: string
          video_url?: string | null
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
          email: string | null
          full_name: string | null
          id: string
          updated_at: string
        }
        ComputedFields: never
        Insert: {
          created_at?: string
          email?: string | null
          full_name?: string | null
          id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          email?: string | null
          full_name?: string | null
          id?: string
          updated_at?: string
        }
        Relationships: []
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
      [_ in never]: never
    }
    Enums: {
      block_role: 'warmup' | 'top' | 'backoff' | 'working'
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
