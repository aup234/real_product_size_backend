defmodule RealProductSizeBackend.Repo.Migrations.AddTripoTaskIdToProducts do
  use Ecto.Migration

  def change do
    alter table(:products) do
      add :tripo_task_id, :string
    end

    create index(:products, [:tripo_task_id])
  end
end
