defmodule RealProductSizeBackend.Crawling.CrawlingHistory do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "crawling_history" do
    field :session_id, :string
    field :source_url, :string
    field :source_type, :string
    field :user_agent, :string
    field :ip_address, :string
    field :started_at, :utc_datetime
    field :completed_at, :utc_datetime
    field :processing_time_ms, :integer
    field :status, :string
    field :error_message, :string
    field :error_code, :string
    field :crawler_version, :string
    field :crawler_config, :map
    field :retry_count, :integer, default: 0
    field :was_blocked, :boolean, default: false
    field :block_reason, :string
    field :captcha_encountered, :boolean, default: false

    belongs_to :user, RealProductSizeBackend.Accounts.User
    belongs_to :product, RealProductSizeBackend.Products.Product

    timestamps(type: :utc_datetime)
  end

  def changeset(crawling_history, attrs) do
    crawling_history
    |> cast(attrs, [
      :session_id,
      :source_url,
      :source_type,
      :user_agent,
      :ip_address,
      :started_at,
      :completed_at,
      :processing_time_ms,
      :status,
      :error_message,
      :error_code,
      :crawler_version,
      :crawler_config,
      :retry_count,
      :was_blocked,
      :block_reason,
      :captcha_encountered,
      :user_id,
      :product_id
    ])
    |> validate_required([:source_url, :source_type, :started_at, :status])
    |> validate_inclusion(:status, ["success", "failed", "partial", "blocked"])
    |> validate_inclusion(:source_type, ["amazon", "ebay", "walmart"])
    |> validate_number(:processing_time_ms, greater_than_or_equal_to: 0)
    |> validate_number(:retry_count, greater_than_or_equal_to: 0)
  end

  def complete_changeset(crawling_history, attrs) do
    crawling_history
    |> cast(attrs, [:completed_at, :processing_time_ms, :status, :error_message, :error_code])
    |> validate_required([:completed_at, :status])
    |> validate_inclusion(:status, ["success", "failed", "partial", "blocked"])
  end
end
