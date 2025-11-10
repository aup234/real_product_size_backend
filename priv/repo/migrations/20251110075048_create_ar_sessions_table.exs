defmodule RealProductSizeBackend.Repo.Migrations.CreateArSessionsTable do
  use Ecto.Migration

  def change do
    create table(:ar_sessions, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :session_token, :string, null: false
      add :device_info, :map
      add :ar_platform, :string

      # Session metrics
      add :started_at, :utc_datetime, null: false
      add :ended_at, :utc_datetime
      add :duration_seconds, :integer

      # AR interactions
      add :product_placed, :boolean, default: false
      add :product_moved, :boolean, default: false
      add :product_scaled, :boolean, default: false
      add :screenshot_taken, :boolean, default: false
      add :recording_started, :boolean, default: false

      # Performance metrics
      add :avg_fps, :decimal, precision: 5, scale: 2
      add :min_fps, :decimal, precision: 5, scale: 2
      add :max_fps, :decimal, precision: 5, scale: 2
      add :memory_usage_mb, :integer
      add :battery_drain_percent, :decimal, precision: 5, scale: 2

      # Errors
      add :error_count, :integer, default: 0
      add :error_details, :map

      add :user_id, references(:users, type: :uuid, on_delete: :delete_all), null: false
      add :product_id, references(:products, type: :uuid, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    # Indexes
    create unique_index(:ar_sessions, [:session_token])
    create index(:ar_sessions, [:user_id])
    create index(:ar_sessions, [:product_id])
    create index(:ar_sessions, [:started_at])
    create index(:ar_sessions, [:ar_platform])
  end
end
