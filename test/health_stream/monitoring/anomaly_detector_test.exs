defmodule HealthStream.Monitoring.AnomalyDetectorTest do
  use ExUnit.Case, async: true

  alias HealthStream.Monitoring.AnomalyDetector
  alias HealthStream.Monitoring.VitalSign
  alias HealthStream.Monitoring.Measurements

  describe "check_anomalies/1" do
    test "returns empty list for normal vital signs" do
      vital_sign =
        build_vital_sign(%{
          heart_rate: 75,
          blood_pressure_sys: 120,
          blood_pressure_dia: 80,
          oxygen_saturation: 98,
          temperature: 98.6
        })

      assert AnomalyDetector.check_anomalies(vital_sign) == []
    end

    test "detects multiple anomalies in single vital sign" do
      vital_sign =
        build_vital_sign(%{
          heart_rate: 110,
          blood_pressure_sys: 160,
          blood_pressure_dia: 95,
          oxygen_saturation: 92,
          temperature: 101.0
        })

      alerts = AnomalyDetector.check_anomalies(vital_sign)

      assert length(alerts) == 4
      assert {:heart_rate, 110, :alert} in alerts
      assert {:blood_pressure, "160/95", :alert} in alerts
      assert {:oxygen_saturation, 92, :alert} in alerts
      assert {:temperature, 101.0, :alert} in alerts
    end
  end

  describe "heart rate anomalies" do
    test "detects bradycardia (low heart rate)" do
      vital_sign = build_vital_sign(%{heart_rate: 55})

      alerts = AnomalyDetector.check_anomalies(vital_sign)

      assert {:heart_rate, 55, :alert} in alerts
    end

    test "detects tachycardia (high heart rate)" do
      vital_sign = build_vital_sign(%{heart_rate: 105})

      alerts = AnomalyDetector.check_anomalies(vital_sign)

      assert {:heart_rate, 105, :alert} in alerts
    end

    test "detects critical bradycardia" do
      vital_sign = build_vital_sign(%{heart_rate: 35})

      alerts = AnomalyDetector.check_anomalies(vital_sign)

      assert {:heart_rate, 35, :critical} in alerts
    end

    test "detects critical tachycardia" do
      vital_sign = build_vital_sign(%{heart_rate: 160})

      alerts = AnomalyDetector.check_anomalies(vital_sign)

      assert {:heart_rate, 160, :critical} in alerts
    end

    test "normal heart rate generates no alerts" do
      for hr <- [60, 75, 90, 100] do
        vital_sign = build_vital_sign(%{heart_rate: hr})
        alerts = AnomalyDetector.check_anomalies(vital_sign)

        refute Enum.any?(alerts, fn {type, _measure, _alert} -> type == :heart_rate end)
      end
    end
  end

  describe "blood pressure anomalies" do
    test "detects hypertension (high blood pressure)" do
      vital_sign =
        build_vital_sign(%{
          blood_pressure_sys: 150,
          blood_pressure_dia: 95
        })

      alerts = AnomalyDetector.check_anomalies(vital_sign)

      assert {:blood_pressure, "150/95", :alert} in alerts
    end

    test "detects critical hypertension" do
      vital_sign =
        build_vital_sign(%{
          blood_pressure_sys: 190,
          blood_pressure_dia: 125
        })

      alerts = AnomalyDetector.check_anomalies(vital_sign)

      assert {:blood_pressure, "190/125", :critical} in alerts
    end

    test "detects hypotension (low blood pressure)" do
      vital_sign =
        build_vital_sign(%{
          blood_pressure_sys: 85,
          blood_pressure_dia: 55
        })

      alerts = AnomalyDetector.check_anomalies(vital_sign)

      assert {:blood_pressure, "85/55", :alert} in alerts
    end

    test "detects hypertension with only systolic elevation" do
      vital_sign =
        build_vital_sign(%{
          blood_pressure_sys: 145,
          blood_pressure_dia: 75
        })

      alerts = AnomalyDetector.check_anomalies(vital_sign)

      assert {:blood_pressure, "145/75", :alert} in alerts
    end

    test "detects hypertension with only diastolic elevation" do
      vital_sign =
        build_vital_sign(%{
          blood_pressure_sys: 130,
          blood_pressure_dia: 95
        })

      alerts = AnomalyDetector.check_anomalies(vital_sign)

      assert {:blood_pressure, "130/95", :alert} in alerts
    end

    test "normal blood pressure generates no alerts" do
      for {sys, dia} <- [{110, 70}, {120, 80}, {135, 85}] do
        vital_sign =
          build_vital_sign(%{
            blood_pressure_sys: sys,
            blood_pressure_dia: dia
          })

        alerts = AnomalyDetector.check_anomalies(vital_sign)

        refute Enum.any?(alerts, fn {type, _, _} -> type == :blood_pressure end)
      end
    end
  end

  describe "oxygen saturation anomalies" do
    test "detects hypoxemia (low oxygen)" do
      vital_sign = build_vital_sign(%{oxygen_saturation: 93})

      alerts = AnomalyDetector.check_anomalies(vital_sign)

      assert {:oxygen_saturation, 93, :alert} in alerts
    end

    test "detects severe hypoxemia (critical)" do
      vital_sign = build_vital_sign(%{oxygen_saturation: 88})

      alerts = AnomalyDetector.check_anomalies(vital_sign)

      assert {:oxygen_saturation, 88, :critical} in alerts
    end

    test "normal oxygen saturation generates no alerts" do
      for o2 <- [95, 97, 99, 100] do
        vital_sign = build_vital_sign(%{oxygen_saturation: o2})
        alerts = AnomalyDetector.check_anomalies(vital_sign)

        refute Enum.any?(alerts, fn {type, _, _} -> type == :oxygen_saturation end)
      end
    end
  end

  describe "temperature anomalies" do
    test "detects hypothermia (low temperature)" do
      vital_sign = build_vital_sign(%{temperature: 96.0})

      alerts = AnomalyDetector.check_anomalies(vital_sign)

      assert {:temperature, 96.0, :alert} in alerts
    end

    test "detects fever (high temperature)" do
      vital_sign = build_vital_sign(%{temperature: 101.5})

      alerts = AnomalyDetector.check_anomalies(vital_sign)

      assert {:temperature, 101.5, :alert} in alerts
    end

    test "detects severe hypothermia (critical)" do
      vital_sign = build_vital_sign(%{temperature: 94.0})

      alerts = AnomalyDetector.check_anomalies(vital_sign)

      assert {:temperature, 94.0, :critical} in alerts
    end

    test "detects hyperthermia (critical high temperature)" do
      vital_sign = build_vital_sign(%{temperature: 105.5})

      alerts = AnomalyDetector.check_anomalies(vital_sign)

      assert {:temperature, 105.5, :critical} in alerts
    end

    test "normal temperature generates no alerts" do
      for temp <- [97.0, 98.6, 99.5, 100.4] do
        vital_sign = build_vital_sign(%{temperature: temp})
        alerts = AnomalyDetector.check_anomalies(vital_sign)

        refute Enum.any?(alerts, fn {type, _, _} -> type == :temperature end)
      end
    end
  end

  describe "edge cases" do
    test "handles boundary values correctly" do
      # Test exact boundary values
      test_cases = [
        # Heart rate boundaries
        # Normal lower bound
        {%{heart_rate: 60}, []},
        # Just below normal
        {%{heart_rate: 59}, [{:heart_rate, 59, :alert}]},
        # Normal upper bound
        {%{heart_rate: 100}, []},
        # Just above normal
        {%{heart_rate: 101}, [{:heart_rate, 101, :alert}]},
        # Critical boundary
        {%{heart_rate: 39}, [{:heart_rate, 39, :critical}]},
        # Critical boundary
        {%{heart_rate: 151}, [{:heart_rate, 151, :critical}]},

        # Temperature boundaries
        # Normal lower bound
        {%{temperature: 97.0}, []},
        # Just below normal
        {%{temperature: 96.9}, [{:temperature, 96.9, :alert}]},
        # Normal upper bound
        {%{temperature: 100.4}, []},
        # Just above normal
        {%{temperature: 100.5}, [{:temperature, 100.5, :alert}]},

        # Oxygen saturation boundaries
        # Normal lower bound
        {%{oxygen_saturation: 95}, []},
        # Just below normal
        {%{oxygen_saturation: 94}, [{:oxygen_saturation, 94, :alert}]},
        # Critical boundary
        {%{oxygen_saturation: 89}, [{:oxygen_saturation, 89, :critical}]}
      ]

      for {measurements, expected_alerts} <- test_cases do
        vital_sign = build_vital_sign(measurements)
        alerts = AnomalyDetector.check_anomalies(vital_sign)

        assert alerts == expected_alerts,
               "Expected #{inspect(expected_alerts)} for #{inspect(measurements)}, got #{inspect(alerts)}"
      end
    end

    test "handles nil measurements gracefully" do
      vital_sign = %VitalSign{
        patient_id: "TEST001",
        device_id: "DEV001",
        measurements: nil
      }

      assert_raise FunctionClauseError, fn ->
        AnomalyDetector.check_anomalies(vital_sign)
      end
    end
  end

  defp build_vital_sign(overrides) do
    defaults = %{
      heart_rate: 75,
      blood_pressure_sys: 120,
      blood_pressure_dia: 80,
      oxygen_saturation: 98,
      temperature: 98.6
    }

    measurements = Map.merge(defaults, overrides)

    %VitalSign{
      patient_id: "TEST001",
      device_id: "DEV001",
      measurements: struct(Measurements, measurements)
    }
  end
end
