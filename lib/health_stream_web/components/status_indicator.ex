defmodule HealthStreamWeb.Components.StatusIndicator do
  @moduledoc """
  Status indicator component with colored dot and text.
  """
  use Phoenix.Component
  use Gettext, backend: HealthStreamWeb.Gettext

  @doc """
  Renders a status indicator with icon and text.

  ## Examples

      <.status_indicator color="success">System Online</.status_indicator>
      <.status_indicator color="info">Live Updates Active</.status_indicator>
      <.status_indicator color="warning">Connection Issues</.status_indicator>
      <.status_indicator color="error">System Offline</.status_indicator>
  """
  attr :color, :string,
    required: true,
    values: ~w(success info warning error),
    doc: "Status color theme"

  slot :inner_block, required: true, doc: "Status text content"

  def status_indicator(assigns) do
    ~H"""
    <div class="flex items-center" role="status">
      <div class={["w-3 h-3 rounded-full mr-2", get_color_class(@color)]} aria-hidden="true"></div>
      <span>{render_slot(@inner_block)}</span>
    </div>
    """
  end

  # Helper function to get color classes
  defp get_color_class("success"), do: "bg-success"
  defp get_color_class("info"), do: "bg-info"
  defp get_color_class("warning"), do: "bg-warning"
  defp get_color_class("error"), do: "bg-error"
end
