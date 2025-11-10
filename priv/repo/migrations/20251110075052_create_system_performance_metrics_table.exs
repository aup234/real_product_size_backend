defmodule RealProductSizeBackend.Repo.Migrations.CreateSystemPerformanceMetricsTable do
  use Ecto.Migration

  def change do
    create table(:system_performance_metrics, primary_key: false) do
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")

      # Metric identification
      add :metric_name, :string, null: false
      add :metric_type, :string, null: false
      add :metric_unit, :string

      # Metric values
      add :value, :decimal, precision: 15, scale: 4, null: false
      add :min_value, :decimal, precision: 15, scale: 4
      add :max_value, :decimal, precision: 15, scale: 4
      add :avg_value, :decimal, precision: 15, scale: 4

      # Context
      add :hostname, :string
      add :process_id, :integer
      add :node_name, :string

      # Timestamps
      add :recorded_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    # Indexes
    create index(:system_performance_metrics, [:metric_name])
    create index(:system_performance_metrics, [:recorded_at])
    create index(:system_performance_metrics, [:hostname])
    create index(:system_performance_metrics, [:metric_type])
  end
end
