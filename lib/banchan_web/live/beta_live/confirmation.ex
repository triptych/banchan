defmodule BanchanWeb.BetaLive.Confirmation do
  @moduledoc """
  Confirmation page for beta signup.
  """
  use BanchanWeb, :surface_view

  alias Surface.Components.LiveRedirect

  alias BanchanWeb.Components.Layout

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, socket |> assign(uri: uri)}
  end

  @impl true
  def render(assigns) do
    ~F"""
    <Layout uri={@uri} current_user={@current_user} flashes={@flash}>
      <div id="above-fold" class="md:px-4">
        <div class="min-h-screen hero">
          <div class="hero-content flex flex-col md:flex-row">
            <div class="flex flex-col gap-6 md:gap-10 items-center max-w-2xl">
              <div class="text-5xl font-bold">
                Thanks for <span class="text-primary font-bold">Signing Up</span>!
              </div>
              <div class="text-xl">
                Beta applications will be processed in the order they were
                received.
              </div>
              <div class="text-xl">
                <a
                  href="https://discord.gg/FUkTHjGKJF"
                  target="_blank"
                  rel="noopener noreferrer"
                  class="btn bg-[#5865F2] btn-md rounded-full"
                >Join our Discord <i class="pl-2 fab fa-discord text-xl" /></a>
              </div>
              <div class="flex flex-row gap-4">
                <LiveRedirect class="link" to={Routes.beta_signup_path(Endpoint, :new)}>Go Back</LiveRedirect>
                |
                <a
                  href="https://twitter.com/share?ref_src=twsrc%5Etfw"
                  class="twitter-share-button link"
                  data-text="Sign up for beta access to Banchan Art, a co-operative platform for art commissions, owned by artists!"
                  data-via="BanchanArt"
                  data-hashtags="#commsopen"
                  data-show-count="false"
                >Tweet</a>
                <script async src="https://platform.twitter.com/widgets.js" charset="utf-8" />
              </div>
              <div class="font-semibold">Follow Us:</div>
              <ul class="flex flex-row gap-4">
                <li>
                  <a href="https://twitter.com/BanchanArt" target="_blank" rel="noopener noreferrer"><i class="fab fa-twitter text-xl" />
                  </a>
                </li>
                <li>
                  <a href="https://instagram.com/BanchanArt" target="_blank" rel="noopener noreferrer"><i class="fab fa-instagram text-xl" />
                  </a>
                </li>
              </ul>
            </div>
          </div>
        </div>
      </div>
    </Layout>
    """
  end
end
