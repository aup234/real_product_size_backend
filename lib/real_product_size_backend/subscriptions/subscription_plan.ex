defmodule RealProductSizeBackend.Subscriptions.SubscriptionPlan do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "subscription_plans" do
    field :name, :string
    field :description, :string
    field :product_id, :string
    field :price_monthly, :decimal
    field :price_yearly, :decimal
    field :features, :map
    field :limits, :map
    field :is_active, :boolean, default: true
    field :sort_order, :integer, default: 0

    timestamps(type: :utc_datetime)
  end

  def changeset(plan, attrs) do
    plan
    |> cast(attrs, [
      :name,
      :description,
      :product_id,
      :price_monthly,
      :price_yearly,
      :features,
      :limits,
      :is_active,
      :sort_order
    ])
    |> validate_required([:name, :product_id])
    |> unique_constraint(:product_id)
  end

  def free_tier_limits do
    %{
      "ar_views" => 5,
      "product_crawls" => 10,
      "model_generations" => 2,
      "storage" => 5
    }
  end

  def get_limits_for_product_id(product_id) do
    case product_id do
      "com.realproductsize.basic.monthly" ->
        %{
          "ar_views" => 50,
          "product_crawls" => 100,
          "model_generations" => 20,
          "storage" => 100
        }

      "com.realproductsize.basic.yearly" ->
        %{
          "ar_views" => 50,
          "product_crawls" => 100,
          "model_generations" => 20,
          "storage" => 100
        }

      "com.realproductsize.pro.monthly" ->
        %{
          "ar_views" => 200,
          "product_crawls" => 500,
          "model_generations" => 100,
          "storage" => 500
        }

      "com.realproductsize.pro.yearly" ->
        %{
          "ar_views" => 200,
          "product_crawls" => 500,
          "model_generations" => 100,
          "storage" => 500
        }

      "com.realproductsize.enterprise.monthly" ->
        %{
          # unlimited
          "ar_views" => -1,
          "product_crawls" => -1,
          "model_generations" => -1,
          "storage" => -1
        }

      _ ->
        free_tier_limits()
    end
  end
end
