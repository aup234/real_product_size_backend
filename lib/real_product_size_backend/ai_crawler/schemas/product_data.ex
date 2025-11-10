defmodule RealProductSizeBackend.AiCrawler.Schemas.Dimensions do
  use Ecto.Schema

  @primary_key false
  @derive {Jason.Encoder, only: [:length, :width, :height, :unit]}

  embedded_schema do
    field :length, :float
    field :width, :float
    field :height, :float
    field :unit, :string, default: "mm"
  end

  def changeset(dimensions, attrs) do
    dimensions
    |> Ecto.Changeset.cast(attrs, [:length, :width, :height, :unit])
    |> validate_changeset()
  end

  def validate_changeset(changeset) do
    changeset
    |> validate_dimensions_if_present()
  end

  defp validate_dimensions_if_present(changeset) do
    # Only validate if the fields are present and not nil
    changeset = if Ecto.Changeset.get_field(changeset, :length) != nil do
      Ecto.Changeset.validate_number(changeset, :length, greater_than_or_equal_to: 0)
    else
      changeset
    end

    changeset = if Ecto.Changeset.get_field(changeset, :width) != nil do
      Ecto.Changeset.validate_number(changeset, :width, greater_than_or_equal_to: 0)
    else
      changeset
    end

    changeset = if Ecto.Changeset.get_field(changeset, :height) != nil do
      Ecto.Changeset.validate_number(changeset, :height, greater_than_or_equal_to: 0)
    else
      changeset
    end

    changeset = if Ecto.Changeset.get_field(changeset, :unit) != nil do
      Ecto.Changeset.validate_inclusion(changeset, :unit, ["mm", "cm", "inches", "in"])
    else
      changeset
    end

    changeset
  end
end

defmodule RealProductSizeBackend.AiCrawler.Schemas.ProductData do
  use Ecto.Schema

  @primary_key false
  @derive {Jason.Encoder, only: [:title, :price, :description, :brand, :material, :availability, :rating, :category, :dimensions, :images]}

  embedded_schema do
    field :title, :string
    field :price, :string
    field :description, :string
    field :brand, :string
    field :material, :string
    field :availability, :string
    field :rating, :string
    field :category, :string
    embeds_one :dimensions, RealProductSizeBackend.AiCrawler.Schemas.Dimensions
    field :images, {:array, :string}
  end

  def changeset(product_data, attrs) do
    product_data
    |> Ecto.Changeset.cast(attrs, [:title, :price, :description, :brand, :material, :availability, :rating, :category, :images])
    |> Ecto.Changeset.cast_embed(:dimensions, required: false)
    |> validate_changeset()
  end

  def validate_changeset(changeset) do
    changeset
    |> Ecto.Changeset.validate_required([:title])
    |> Ecto.Changeset.validate_length(:title, max: 200)
    |> validate_dimensions_if_present()
  end

  defp validate_dimensions_if_present(changeset) do
    case Ecto.Changeset.get_field(changeset, :dimensions) do
      nil -> changeset
      dimensions when is_struct(dimensions) ->
        # Only validate if dimensions are present and not null
        if dimensions.length != nil or dimensions.width != nil or dimensions.height != nil do
          # Validate the dimensions struct, not the product data
          dimensions_changeset = RealProductSizeBackend.AiCrawler.Schemas.Dimensions.changeset(dimensions, %{})
          if dimensions_changeset.valid? do
            changeset
          else
            Ecto.Changeset.add_error(changeset, :dimensions, "Invalid dimensions")
          end
        else
          changeset
        end
      _ -> changeset
    end
  end
end
