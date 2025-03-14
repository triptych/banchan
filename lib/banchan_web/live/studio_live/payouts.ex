defmodule BanchanWeb.StudioLive.Payouts do
  @moduledoc """
  Studio payouts page.
  """
  use BanchanWeb, :surface_view

  import BanchanWeb.StudioLive.Helpers

  alias Banchan.Payments

  alias BanchanWeb.Components.{Button, InfiniteScroll}
  alias BanchanWeb.StudioLive.Components.{Payout, PayoutRow, StudioLayout}

  def mount(params, _session, socket) do
    {:ok, assign_studio_defaults(params, socket, true, true)}
  end

  @impl true
  def handle_params(params, uri, socket) do
    if socket.redirected do
      {:noreply, socket}
    else
      Payments.subscribe_to_payout_events(socket.assigns.studio)

      payout_id =
        case params do
          %{"payout_id" => payout_id} ->
            # NOTE: Phoenix LiveView's push_patch has an obnoxious bug with fragments, so
            # we have to manually remove them here.
            # See: https://github.com/phoenixframework/phoenix_live_view/issues/2041
            Regex.replace(~r/#.*$/, payout_id, "")

          _ ->
            nil
        end

      send(self(), :load_data)

      payout =
        if is_nil(payout_id) do
          nil
        else
          Map.get(socket.assigns, :payout, nil)
        end

      {:noreply,
       socket
       |> assign(uri: uri)
       |> assign(payout_id: payout_id)
       |> assign(data_pending: true)
       |> assign(fypm_pending: false)
       |> assign(page: 1)
       |> assign(payout: payout)
       |> assign(results: Map.get(socket.assigns, :results, nil))
       |> assign(balance: Map.get(socket.assigns, :balance, nil))}
    end
  end

  def handle_event("load_more", _, socket) do
    if socket.assigns.results.total_entries >
         socket.assigns.page * socket.assigns.results.page_size do
      {:noreply, socket |> assign(page: socket.assigns.page + 1) |> fetch()}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("fypm", _, socket) do
    send(self(), :process_fypm)
    {:noreply, socket |> assign(fypm_pending: true)}
  end

  def handle_info(:load_data, socket) do
    payout =
      if socket.assigns.payout_id do
        Task.async(fn -> Payments.get_payout!(socket.assigns.payout_id) end)
      else
        Task.async(fn -> nil end)
      end

    results =
      Task.async(fn -> Payments.list_payouts(socket.assigns.studio, socket.assigns.page) end)

    balance = Task.async(fn -> Payments.get_banchan_balance(socket.assigns.studio) end)

    [payout, results, {:ok, balance}] = Task.await_many([payout, results, balance])

    {:noreply,
     socket
     |> assign(data_pending: false)
     |> assign(payout: payout)
     |> assign(results: results)
     |> assign(balance: balance)}
  end

  def handle_info(:process_fypm, socket) do
    case Payments.payout_studio(socket.assigns.current_user, socket.assigns.studio) do
      {:ok, [payout, _ | _]} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Payouts sent! They should be in your account(s) starting #{payout.arrival_date |> Timex.to_datetime() |> Timex.format!("{relative}", :relative)}."
         )}

      {:ok, [payout | _]} ->
        {:noreply,
         socket
         |> put_flash(
           :info,
           "Payout sent! It should be in your account #{payout.arrival_date |> Timex.to_datetime() |> Timex.format!("{relative}", :relative)}."
         )}

      {:error, %Stripe.Error{user_message: user_message}} ->
        {:noreply,
         socket
         |> assign(fypm_pending: false)
         |> put_flash(:error, "Payout failed: #{user_message}")}

      {:error, _err} ->
        {:noreply,
         socket
         |> assign(fypm_pending: false)
         |> put_flash(:error, "Payout failed due to an internal error.")}
    end
  end

  def handle_info(%{event: "payout_updated", payload: payout}, socket) do
    new_payout =
      if socket.assigns.payout && socket.assigns.payout.id == payout.id do
        payout
      else
        socket.assigns.payout
      end

    in_result = Enum.find(socket.assigns.results.entries, &(&1.id == payout.id))

    new_results =
      if in_result do
        new_entries =
          Enum.map(socket.assigns.results.entries, fn entry ->
            if entry.id == payout.id do
              payout
            else
              entry
            end
          end)

        Task.async(fn -> %{socket.assigns.results | entries: new_entries} end)
      else
        Task.async(fn -> Payments.list_payouts(socket.assigns.studio, socket.assigns.page) end)
      end

    new_balance = Task.async(fn -> Payments.get_banchan_balance(socket.assigns.studio) end)

    [new_results, {:ok, new_balance}] = Task.await_many([new_results, new_balance])

    {:noreply,
     socket
     |> assign(
       payout: new_payout,
       results: new_results,
       balance: new_balance,
       fypm_pending: false
     )}
  end

  def handle_info(%{event: "follower_count_changed", payload: new_count}, socket) do
    {:noreply, socket |> assign(followers: new_count)}
  end

  defp payout_possible?(available) do
    !Enum.empty?(available) &&
      Enum.all?(available, &(&1.amount > 0))
  end

  defp fetch(%{assigns: %{results: results, page: page}} = socket) do
    socket
    |> assign(
      :results,
      %{
        results
        | entries:
            results.entries ++
              Payments.list_payouts(socket.assigns.studio, page).entries
      }
    )
  end

  @impl true
  def render(assigns) do
    ~F"""
    <StudioLayout
      id="studio-layout"
      current_user={@current_user}
      flashes={@flash}
      studio={@studio}
      followers={@followers}
      current_user_member?={@current_user_member?}
      tab={:payouts}
      uri={@uri}
    >
      <div class="flex flex-col grow max-h-full">
        <div class="flex flex-row grow md:grow-0">
          <div class={"flex flex-col basis-full md:basis-1/4 px-4 sidebar", "hidden md:flex": @payout_id}>
            <div id="available" class="flex flex-col">
              {#if is_nil(@balance) || !payout_possible?(@balance.available)}
                <h2 class="text-xl2">No Balance Available</h2>
              {#else}
                <div class="stats stats-horizontal">
                  {#if @balance}
                    {#for avail <- @balance.available}
                      {#if avail.amount > 0}
                        <div class="stat">
                          <div class="stat-value">{Money.to_string(avail)}</div>
                          <div class="stat-desc">Available for Payout</div>
                        </div>
                      {/if}
                    {/for}
                  {/if}
                </div>
              {/if}
              <Button
                click="fypm"
                disabled={@fypm_pending || is_nil(@balance) || !payout_possible?(@balance.available)}
              >
                {#if @fypm_pending}
                  <i class="px-2 fas fa-spinner animate-spin" />
                {/if}
                Pay Out
              </Button>
              <div class="divider">History</div>
              <ul class="payout-rows menu menu-compact p-2">
                {#if @results}
                  {#for payout <- @results.entries}
                    <PayoutRow studio={@studio} payout={payout} highlight={@payout_id == payout.public_id} />
                  {/for}
                {/if}
              </ul>
              <InfiniteScroll id="payouts-infinite-scroll" page={@page} load_more="load_more" />
            </div>
          </div>
          {#if @payout_id}
            <div class="px-4 md:container basis-full md:basis-3/4 payout">
              <Payout
                id="payout"
                current_user={@current_user}
                studio={@studio}
                payout={@payout}
                data_pending={@data_pending}
              />
            </div>
          {/if}
        </div>
      </div>
    </StudioLayout>
    """
  end
end
