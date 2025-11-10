defmodule RealProductSizeBackend.Repo.Migrations.CreateErrorTrackingTable do
  use Ecto.Migration

  def change do
    create table(:error_tracking, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Error identification
      add :error_type, :string, null: false
      add :error_code, :string
      add :error_message, :text, null: false

      # Context
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all)
      add :session_id, :string
      add :request_id, :string

      # Error details
      add :stack_trace, :text
      add :error_context, :map
      add :severity, :string, default: "error"

      # Environment
      add :environment, :string, null: false
      add :version, :string
      add :hostname, :string

      # Occurrence tracking
      add :occurrence_count, :integer, default: 1
      add :first_occurred_at, :utc_datetime, null: false
      add :last_occurred_at, :utc_datetime, null: false

      # Resolution
      add :is_resolved, :boolean, default: false
      add :resolved_at, :utc_datetime
      add :resolution_notes, :text

      timestamps(type: :utc_datetime)
    end

    # Indexes
    create index(:error_tracking, [:error_type])
    create index(:error_tracking, [:severity])
    create index(:error_tracking, [:user_id])
    create index(:error_tracking, [:first_occurred_at])
    create index(:error_tracking, [:is_resolved])
    create index(:error_tracking, [:environment])
  end
end
