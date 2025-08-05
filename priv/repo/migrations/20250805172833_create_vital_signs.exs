defmodule HealthStream.Repo.Migrations.CreateVitalSigns do
  use Ecto.Migration

  def change do
    create table(:vital_signs) do
      add :patient_id, :string, null: false
      add :device_id, :string, null: false
      add :measurements, :map, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create index(:vital_signs, [:patient_id])
  end
end
