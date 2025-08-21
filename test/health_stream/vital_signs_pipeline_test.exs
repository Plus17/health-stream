defmodule HealthStream.VitalSignsPipelineTest do
  use HealthStream.DataCase, async: true

  alias HealthStream.VitalSignsPipeline
  alias HealthStream.Monitoring.VitalSign
  alias HealthStream.Monitoring.Measurements

  describe "handle_message/3" do
    test "processes valid vital sign message successfully" do
      valid_data = %{
        "patient_id" => "patient-123",
        "device_id" => "device-456",
        "measurements" => %{
          "heart_rate" => 80,
          "blood_pressure_sys" => 120,
          "blood_pressure_dia" => 80,
          "oxygen_saturation" => 98,
          "temperature" => 82
        }
      }

      json_data = Jason.encode!(valid_data)

      ref = Broadway.test_message(VitalSignsPipeline, json_data)

      assert_receive {:ack, ^ref, [%{data: %VitalSign{} = vital_sign}], []}, 1000

      assert vital_sign.patient_id == "patient-123"
      assert vital_sign.device_id == "device-456"

      assert vital_sign.measurements == %Measurements{
               blood_pressure_dia: 80,
               blood_pressure_sys: 120,
               heart_rate: 80,
               oxygen_saturation: 98,
               temperature: 82.0
             }
    end
  end
end
