defmodule BanchanWeb.StaticLive.Membership do
  @moduledoc """
  Banchan Membership Page
  """
  use BanchanWeb, :surface_view

  alias Surface.Components.Markdown

  alias BanchanWeb.Components.Layout

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, socket |> assign(uri: uri)}
  end

  @impl true
  def render(assigns) do
    ~F"""
    <Layout uri={@uri} current_user={@current_user} flashes={@flash}>
      <#Markdown class="prose">
        # Joining Banchan

        We're still working on our membership system. Come back soon.
      </#Markdown>
    </Layout>
    """
  end
end
