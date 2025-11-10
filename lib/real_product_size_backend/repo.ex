defmodule RealProductSizeBackend.Repo do
  use Ecto.Repo,
    otp_app: :real_product_size_backend,
    adapter: Ecto.Adapters.Postgres
end
