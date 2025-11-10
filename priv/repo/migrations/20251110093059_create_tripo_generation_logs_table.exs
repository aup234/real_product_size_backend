defmodule RealProductSizeBackend.Repo.Migrations.CreateTripoGenerationLogsTable do
  use Ecto.Migration

  def change do
    create table(:tripo_generation_logs, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :product_id, references(:products, type: :uuid, on_delete: :delete_all), null: false
      add :task_id, :string, null: false
      add :status, :string, null: false
      add :progress, :integer, default: 0
      add :request_payload, :map
      add :response_data, :map
      add :pbr_model_url, :text
      add :local_model_path, :text
      add :rendered_image_url, :text
      add :generated_image_url, :text
      add :error_message, :text

      timestamps(type: :utc_datetime)
    end

    create index(:tripo_generation_logs, [:product_id])
    create unique_index(:tripo_generation_logs, [:task_id])
    create index(:tripo_generation_logs, [:status])
  end
end
