defmodule RealProductSizeBackend.Repo.Migrations.CreateApiRequestLogsTable do
  use Ecto.Migration

  def change do
    create table(:api_request_logs, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Request identification
      add :request_id, :string, null: false
      add :user_id, references(:users, type: :uuid, on_delete: :delete_all)
      add :session_id, :string

      # Request details
      add :method, :string, null: false
      add :endpoint, :string, null: false
      add :path_params, :map
      add :query_params, :map
      add :request_body_size, :integer

      # Client information
      add :user_agent, :text
      add :ip_address, :string
      add :country_code, :string
      add :timezone, :string

      # Performance metrics
      add :started_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime
      add :processing_time_ms, :integer
      add :database_query_count, :integer
      add :database_query_time_ms, :integer

      # Response details
      add :status_code, :integer, null: false
      add :response_size, :integer
      add :error_message, :text
      add :error_stack, :text

      # Rate limiting
      add :rate_limit_bucket, :string
      add :rate_limit_remaining, :integer
      add :rate_limit_reset_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    # Indexes for analytics queries
    create unique_index(:api_request_logs, [:request_id])
    create index(:api_request_logs, [:user_id])
    create index(:api_request_logs, [:endpoint])
    create index(:api_request_logs, [:status_code])
    create index(:api_request_logs, [:started_at])
    create index(:api_request_logs, [:processing_time_ms])
    create index(:api_request_logs, [:country_code])
    create index(:api_request_logs, [:method])
  end
end
