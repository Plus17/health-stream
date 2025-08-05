defmodule HealthStream.MonitoringTest do
  use HealthStream.DataCase

  alias HealthStream.Monitoring

  describe "vital_signs" do
    alias HealthStream.Monitoring.VitalSign
    alias HealthStream.Monitoring.Measurements

    import HealthStream.MonitoringFixtures

    @invalid_attrs %{patient_id: nil, device_id: nil, measurements: nil, inserted_at: nil}

    test "list_vital_signs/0 returns all vital_signs" do
      vital_sign = vital_sign_fixture()
      assert Monitoring.list_vital_signs() == [vital_sign]
    end

    test "get_vital_sign!/1 returns the vital_sign with given id" do
      vital_sign = vital_sign_fixture()
      assert Monitoring.get_vital_sign!(vital_sign.id) == vital_sign
    end

    test "create_vital_sign/1 with valid data creates a vital_sign" do
      valid_attrs = %{
        patient_id: "some patient_id",
        device_id: "some device_id",
        measurements: %{
          heart_rate: 80,
          blood_pressure_sys: 120,
          blood_pressure_dia: 80,
          oxygen_saturation: 98,
          temperature: 82
        }
      }

      assert {:ok, %VitalSign{} = vital_sign} = Monitoring.create_vital_sign(valid_attrs)
      assert vital_sign.patient_id == "some patient_id"
      assert vital_sign.device_id == "some device_id"

      assert vital_sign.measurements == %Measurements{
               heart_rate: 80,
               blood_pressure_sys: 120,
               blood_pressure_dia: 80,
               oxygen_saturation: 98,
               temperature: 82
             }
    end

    test "create_vital_sign/1 with invalid data returns error changeset" do
      assert {:error, %Ecto.Changeset{}} = Monitoring.create_vital_sign(@invalid_attrs)
    end

    test "delete_vital_sign/1 deletes the vital_sign" do
      vital_sign = vital_sign_fixture()
      assert {:ok, %VitalSign{}} = Monitoring.delete_vital_sign(vital_sign)
      assert_raise Ecto.NoResultsError, fn -> Monitoring.get_vital_sign!(vital_sign.id) end
    end

    test "change_vital_sign/1 returns a vital_sign changeset" do
      vital_sign = vital_sign_fixture()
      assert %Ecto.Changeset{} = Monitoring.change_vital_sign(vital_sign)
    end
  end
end
