defmodule RealProductSizeBackend.ArSessions.ArSession do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "ar_sessions" do
    field :session_token, :string
    field :device_info, :map
    field :ar_platform, :string

    # Session metrics
    field :started_at, :utc_datetime
    field :ended_at, :utc_datetime
    field :duration_seconds, :integer

    # AR interactions
    field :product_placed, :boolean, default: false
    field :product_moved, :boolean, default: false
    field :product_scaled, :boolean, default: false
    field :screenshot_taken, :boolean, default: false
    field :recording_started, :boolean, default: false

    # Performance metrics
    field :avg_fps, :decimal
    field :min_fps, :decimal
    field :max_fps, :decimal
    field :memory_usage_mb, :integer
    field :battery_drain_percent, :decimal

    # Errors
    field :error_count, :integer, default: 0
    field :error_details, :map

    belongs_to :user, RealProductSizeBackend.Accounts.User
    belongs_to :product, RealProductSizeBackend.Products.Product

    timestamps(type: :utc_datetime)
  end

  def changeset(ar_session, attrs) do
    ar_session
    |> cast(attrs, [
      :session_token,
      :device_info,
      :ar_platform,
      :started_at,
      :ended_at,
      :duration_seconds,
      :product_placed,
      :product_moved,
      :product_scaled,
      :screenshot_taken,
      :recording_started,
      :avg_fps,
      :min_fps,
      :max_fps,
      :memory_usage_mb,
      :battery_drain_percent,
      :error_count,
      :error_details,
      :user_id,
      :product_id
    ])
    |> validate_required([:session_token, :started_at, :user_id, :product_id])
    |> unique_constraint(:session_token)
    |> validate_inclusion(:ar_platform, ["arkit", "arcore", "webxr"])
    |> validate_number(:duration_seconds, greater_than_or_equal_to: 0)
    |> validate_number(:error_count, greater_than_or_equal_to: 0)
  end

  def end_session_changeset(ar_session, attrs) do
    ar_session
    |> cast(attrs, [
      :ended_at,
      :duration_seconds,
      :avg_fps,
      :min_fps,
      :max_fps,
      :memory_usage_mb,
      :battery_drain_percent
    ])
    |> validate_required([:ended_at])
    |> validate_number(:duration_seconds, greater_than: 0)
  end
end
