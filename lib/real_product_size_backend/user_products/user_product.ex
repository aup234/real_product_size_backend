defmodule RealProductSizeBackend.UserProducts.UserProduct do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "user_products" do
    field :notes, :string
    field :tags, {:array, :string}
    field :favorite, :boolean, default: false
    field :ar_view_count, :integer, default: 0
    field :last_ar_view_at, :utc_datetime

    belongs_to :user, RealProductSizeBackend.Accounts.User
    belongs_to :product, RealProductSizeBackend.Products.Product

    timestamps(type: :utc_datetime)
  end

  def changeset(user_product, attrs) do
    user_product
    |> cast(attrs, [
      :user_id,
      :product_id,
      :notes,
      :tags,
      :favorite,
      :ar_view_count,
      :last_ar_view_at
    ])
    |> validate_required([:user_id, :product_id])
    |> unique_constraint([:user_id, :product_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:product_id)
    |> validate_number(:ar_view_count, greater_than_or_equal_to: 0)
  end

  def increment_ar_view_changeset(user_product) do
    user_product
    |> change(%{
      ar_view_count: user_product.ar_view_count + 1,
      last_ar_view_at: DateTime.utc_now()
    })
  end
end
