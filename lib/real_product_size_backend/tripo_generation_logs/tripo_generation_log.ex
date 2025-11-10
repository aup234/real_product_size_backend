defmodule RealProductSizeBackend.TripoGenerationLogs.TripoGenerationLog do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "tripo_generation_logs" do
    field :task_id, :string
    field :status, :string
    field :progress, :integer, default: 0
    field :request_payload, :map
    field :response_data, :map
    field :pbr_model_url, :string
    field :local_model_path, :string
    field :rendered_image_url, :string
    field :generated_image_url, :string
    field :error_message, :string

    belongs_to :product, RealProductSizeBackend.Products.Product

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(log, attrs) do
    log
    |> cast(attrs, [
      :product_id,
      :task_id,
      :status,
      :progress,
      :request_payload,
      :response_data,
      :pbr_model_url,
      :local_model_path,
      :rendered_image_url,
      :generated_image_url,
      :error_message
    ])
    |> validate_required([:product_id, :task_id, :status])
    |> validate_inclusion(:progress, 0..100)
    |> foreign_key_constraint(:product_id)
    |> unique_constraint(:task_id)
  end
end
