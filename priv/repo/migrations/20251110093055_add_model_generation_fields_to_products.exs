defmodule RealProductSizeBackend.Repo.Migrations.AddModelGenerationFieldsToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :model_generation_status, :string, default: "pending"
      add :model_generated_at, :utc_datetime
      add :model_generation_job_id, :string
    end
  end
end
