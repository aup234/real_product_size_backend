defmodule RealProductSizeBackend.Repo.Migrations.CreateCrawlingHistoryTable do
  use Ecto.Migration

  def change do
    create table(:crawling_history, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :session_id, :string
      add :source_url, :text, null: false
      add :source_type, :string, null: false
      add :user_agent, :text
      add :ip_address, :string
      add :started_at, :utc_datetime, null: false
      add :completed_at, :utc_datetime
      add :processing_time_ms, :integer
      add :status, :string, null: false
      add :error_message, :text
      add :error_code, :string
      add :crawler_version, :string
      add :crawler_config, :map
      add :retry_count, :integer, default: 0
      add :was_blocked, :boolean, default: false
      add :block_reason, :string
      add :captcha_encountered, :boolean, default: false

      add :user_id, references(:users, type: :uuid, on_delete: :delete_all)
      add :product_id, references(:products, type: :uuid, on_delete: :delete_all)

      timestamps(type: :utc_datetime)
    end

    # Indexes
    create index(:crawling_history, [:user_id])
    create index(:crawling_history, [:session_id])
    create index(:crawling_history, [:source_url])
    create index(:crawling_history, [:status])
    create index(:crawling_history, [:started_at])
    create index(:crawling_history, [:was_blocked])
    create index(:crawling_history, [:source_type])
  end
end
