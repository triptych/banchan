defmodule BanchanWeb.CommissionLive.Components.InvoiceBox do
  @moduledoc """
  This is what shows up on the commission timeline when an artist asks for payment.
  """
  use BanchanWeb, :live_component

  alias Banchan.Commissions.Event
  alias Banchan.Payments
  alias Banchan.Utils

  alias Surface.Components.{Form, LiveRedirect}

  alias BanchanWeb.Components.{Button, Modal}
  alias BanchanWeb.Components.Form.{Submit, TextInput}

  prop current_user_member?, :boolean, required: true
  prop current_user, :struct, required: true
  prop commission, :struct, required: true
  prop event, :struct, required: true
  prop uri, :string, required: true

  # NOTE: We're not actually going to create an event directly. We're just
  # punning off this for the changeset validation.
  data changeset, :struct, default: %Event{} |> Event.amount_changeset(%{})

  data release_modal_open, :boolean, default: false

  data refund_error_message, :string, default: nil

  defp replace_fragment(uri, event) do
    URI.to_string(%{URI.parse(uri) | fragment: "event-#{event.public_id}"})
  end

  @impl true
  def handle_event("change", %{"event" => %{"amount" => amount}}, socket) do
    changeset =
      %Event{}
      |> Event.amount_changeset(%{
        "amount" => Utils.moneyfy(amount, socket.assigns.event.invoice.amount.currency)
      })
      |> Map.put(:action, :insert)

    {:noreply, socket |> assign(:changeset, changeset)}
  end

  @impl true
  def handle_event("submit", %{"event" => %{"amount" => amount}}, socket) do
    changeset =
      %Event{}
      |> Event.amount_changeset(%{
        "amount" => Utils.moneyfy(amount, socket.assigns.event.invoice.amount.currency)
      })
      |> Map.put(:action, :insert)

    if changeset.valid? do
      Payments.process_payment(
        socket.assigns.current_user,
        socket.assigns.event,
        socket.assigns.commission,
        replace_fragment(socket.assigns.uri, socket.assigns.event),
        Utils.moneyfy(amount, socket.assigns.event.invoice.amount.currency)
      )
      |> case do
        {:ok, url} ->
          {:noreply, socket |> redirect(external: url)}

        {:error, :payment_failed} ->
          {:noreply,
           socket
           |> put_flash(
             :error,
             "Something went wrong while processing your payment, please try again."
           )
           |> push_redirect(
             to: Routes.commission_path(Endpoint, :show, socket.assigns.commission.public_id)
           )}
      end
    else
      {:noreply, socket |> assign(:changeset, changeset)}
    end
  end

  @impl true
  def handle_event("continue_payment", _, socket) do
    uri = socket.assigns.event.invoice && socket.assigns.event.invoice.checkout_url

    if uri do
      {:noreply, socket |> redirect(external: uri)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("force_expire", _, socket) do
    Payments.expire_payment(
      socket.assigns.current_user,
      socket.assigns.event.invoice
    )
    |> case do
      {:ok, _} ->
        {:noreply, socket}

      {:error, _} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "Something went wrong while expiring your payment, please try again."
         )
         |> push_redirect(
           to: Routes.commission_path(Endpoint, :show, socket.assigns.commission.public_id)
         )}
    end
  end

  def handle_event(
        "refund",
        _,
        %{
          assigns: %{
            current_user: current_user,
            event: event
          }
        } = socket
      ) do
    case Payments.refund_payment(
           current_user,
           event.invoice
         ) do
      {:ok, _} ->
        Modal.hide(socket.assigns.id <> "_refund_modal")
        {:noreply, socket |> assign(refund_error_message: nil)}

      {:error, %Stripe.Error{} = error} ->
        {:noreply,
         socket
         |> assign(refund_error_message: "Failed to refund payment: #{error.user_message}")}

      {:error, :blocked} ->
        {:noreply,
         socket
         |> put_flash(:error, "You are blocked from further interaction with this studio.")
         |> push_redirect(
           to: Routes.commission_path(Endpoint, :show, socket.assigns.commission.public_id)
         )}

      {:error, _} ->
        {:noreply,
         socket
         |> assign(refund_error_message: "Refund failed.")}
    end
  end

  def handle_event(
        "release",
        _,
        %{
          assigns: %{current_user: current_user, commission: commission, event: event}
        } = socket
      ) do
    Payments.release_payment(
      current_user,
      commission,
      event.invoice
    )
    |> case do
      {:ok, _} ->
        Modal.hide(socket.assigns.id <> "_release_modal")
        {:noreply, socket}

      {:error, :invalid_invoice_status} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to release invoice, possibly due to a state change")
         |> push_redirect(
           to: Routes.commission_path(Endpoint, :show, socket.assigns.commission.public_id)
         )}

      {:error, :blocked} ->
        {:noreply,
         socket
         |> put_flash(:error, "You are blocked from further interaction with this studio.")
         |> push_redirect(
           to: Routes.commission_path(Endpoint, :show, socket.assigns.commission.public_id)
         )}

      {:error, :unauthorized} ->
        {:noreply,
         socket
         |> put_flash(:error, "You are not authorized to access that commission.")
         |> push_redirect(to: Routes.home_path(Endpoint, :index))}

      {:error, :disabled} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "You are not authorized to access that commission because your account has been disabled."
         )
         |> push_redirect(to: Routes.home_path(Endpoint, :index))}
    end
  end

  def handle_event("open_release_modal", _, socket) do
    Modal.show(socket.assigns.id <> "_release_modal")
    {:noreply, socket}
  end

  def handle_event("open_refund_modal", _, socket) do
    Modal.show(socket.assigns.id <> "_refund_modal")
    {:noreply, socket |> assign(refund_error_message: nil)}
  end

  def render(assigns) do
    ~F"""
    <div class="flex flex-col invoice-box">
      {!-- Invoice box --}
      <div class="place-self-center stats">
        <div class="stat">
          {#case @event.invoice.status}
            {#match :pending}
              {#if @current_user.id == @commission.client_id}
                <div class="stat-title">Payment Requested</div>
                <div class="stat-value">{Money.to_string(@event.invoice.amount)}</div>
                <div class="stat-desc">Please consider adding a tip!</div>
                <Form for={@changeset} class="stat-actions flex flex-col gap-2" change="change" submit="submit">
                  <div class="flex flex-row gap-2">
                    {Money.Currency.symbol(@event.invoice.amount)}
                    <TextInput name={:amount} show_label={false} opts={placeholder: "Tip"} />
                  </div>
                  <Submit class="pay-invoice btn-sm w-full" changeset={@changeset} label="Pay" />
                  {#if @current_user_member?}
                    <Button
                      class="cancel-payment-request btn-xs btn-link w-full"
                      click="force_expire"
                      label="Cancel Payment"
                    />
                  {/if}
                </Form>
              {#else}
                <div class="stat-title">Payment Requested</div>
                <div class="stat-value">{Money.to_string(@event.invoice.amount)}</div>
                <div class="stat-desc">Waiting for Payment</div>
                {#if @current_user_member?}
                  <div class="stat-actions">
                    <Button
                      class="cancel-payment-request btn-xs btn-link btn-warning"
                      primary={false}
                      click="force_expire"
                      label="Cancel Payment"
                    />
                  </div>
                {/if}
              {/if}
            {#match :submitted}
              <div class="stat-title">Payment in Process</div>
              <div class="stat-value">{Money.to_string(@event.invoice.amount)}</div>
              {#if @event.invoice.tip.amount > 0}
                <div class="stat-desc">Tip: +{Money.to_string(@event.invoice.tip)} ({Float.round(@event.invoice.tip.amount / @event.invoice.amount.amount * 100)}%)</div>
              {/if}
              <div class="stat-actions">
                <div class="flex flex-col gap-2">
                  {#if @current_user.id == @commission.client_id}
                    <Button class="continue-payment btn-sm" click="continue_payment" label="Continue Payment" />
                  {/if}
                  {#if @current_user_member?}
                    <Button
                      primary={false}
                      class="cancel-payment-request btn-xs btn-link"
                      click="force_expire"
                      label="Cancel Payment"
                    />
                  {/if}
                </div>
              </div>
            {#match :expired}
              <div class="stat-title text-warning">Payment session expired.</div>
              <div class="stat-value">{Money.to_string(@event.invoice.amount)}</div>
              <div class="stat-desc">You'll need to start a new session.</div>
            {#match :succeeded}
              <div class="stat-title">Payment Succeeded</div>
              <div class="stat-value">{Money.to_string(@event.invoice.amount)}</div>
              {#if @event.invoice.tip.amount > 0}
                <div class="stat-desc">Tip: +{Money.to_string(@event.invoice.tip)} ({Float.round(@event.invoice.tip.amount / @event.invoice.amount.amount * 100)}%)</div>
              {/if}
              <div class="stat-actions">
                <div class="flex flex-col gap-2">
                  {#if @current_user_member?}
                    <Button
                      label="Refund Payment"
                      click="open_refund_modal"
                      class="open-refund-modal modal-button btn-xs btn-link w-full"
                    />
                  {/if}
                  {#if @current_user.id == @commission.client_id}
                    <Button
                      label="Release Now"
                      click="open_release_modal"
                      class="open-release-modal modal-button btn-link btn-xs w-full"
                    />
                  {/if}
                </div>
              </div>
            {#match :released}
              <div class="stat-title">Payment Released to Studio</div>
              <div class="stat-value">{Money.to_string(@event.invoice.amount)}</div>
              {#if @event.invoice.tip.amount > 0}
                <div class="stat-desc">Tip: +{Money.to_string(@event.invoice.tip)} ({Float.round(@event.invoice.tip.amount / @event.invoice.amount.amount * 100)}%)</div>
              {/if}
            {#match :refunded}
              <div class="stat-title text-warning">Payment Refunded</div>
              <div class="stat-value">{Money.to_string(@event.invoice.amount)}</div>
              {#if @event.invoice.tip.amount > 0}
                <div class="stat-desc">Tip: +{Money.to_string(@event.invoice.tip)} ({Float.round(@event.invoice.tip.amount / @event.invoice.amount.amount * 100)}%)</div>
              {/if}
              <div class="stat-desc">Payment has been refunded to the client.</div>
            {#match nil}
              {!-- NOTE: This state happens for a very brief window of time
                between when the payment request event is created, and when the
                Invoice itself is created, where there _is_ no
                Invoice for the event. If it's anything but a quick flash,
                there's probably a bug. --}
              <div class="stat-title text-warning">Payment Refunded</div>
              <div class="stat-value">{Money.to_string(@event.invoice.amount)}</div>
              <div class="stat-desc">Please wait...</div>
          {/case}
        </div>
      </div>

      {!-- Footer/Extra info --}
      {#if !is_nil(@event.invoice.refund_status)}
        <span class="italic p-4 text-xs">
          {#case @event.invoice.refund_status}
            {#match :pending}
              A refund is pending for this payment.
            {#match :failed}
              Refund failed
              {#case @event.invoice.refund_failure_reason}
                {#match :lost_or_stolen_card}
                  due to a lost or stolen card.
                {#match :expired_or_canceled_card}
                  due to an expired or canceled card.
                {#match :unknown}
                  for an unknown reason. Please reach out to support.
              {/case}
            {#match :canceled}
              A refund was submitted but was canceled.
            {#match :requires_action}
              A refund was submitted but requires further action.
              {#if @current_user.id == @commission.client_id}
                Stripe will contact you for next steps, if they haven't already. Please check your email.
              {/if}
            {#match _}
          {/case}
        </span>
      {#elseif @event.invoice.status == :succeeded}
        <span class="italic p-4 text-xs">
          Note: Banchan.Art will hold all funds for this commission until a final draft is approved. (<LiveRedirect
            class="link font-semibold"
            to={Routes.commission_receipt_path(Endpoint, :show, @commission.public_id, @event.public_id)}
          >Receipt</LiveRedirect>)
        </span>
      {#elseif @event.invoice.status == :released}
        <span class="italic p-4 text-xs">
          Note: Banchan.Art has released these funds to the studio for payout.
          {#if @current_user_member?}
            (<LiveRedirect
              to={Routes.studio_payouts_path(Endpoint, :index, @commission.studio.handle)}
              class="link font-semibold"
            >Go to Studio Payouts</LiveRedirect>)
            (<LiveRedirect
              class="link font-semibold"
              to={Routes.commission_receipt_path(Endpoint, :show, @commission.public_id, @event.public_id)}
            >Receipt</LiveRedirect>)
          {/if}
        </span>
      {/if}

      {!-- Refund confirmation modal --}
      <Modal id={@id <> "_refund_modal"} class="refund-modal">
        <:title>Confirm Refund</:title>
        {#if @refund_error_message}
          <p class="alert alert-error" role="alert">{@refund_error_message}</p>
        {/if}
        Are you sure you want to refund this payment?
        <p class="font-bold text-warning">
          NOTE: The Banchan platform fee will not be reimbursed, just the portion that would go to the studio.
        </p>
        <:action>
          <Button class="refund-btn" click="refund">Confirm</Button>
        </:action>
      </Modal>

      {!-- Release confirmation modal --}
      <Modal id={@id <> "_release_modal"} class="release-modal">
        <:title>Confirm Fund Release</:title>
        Funds will be made available immediately to the studio, instead of waiting until the commission is approved. <p class="font-bold text-warning">WARNING: This is final and you won't be able to request a refund from the studio after this.</p>
        <:action>
          <Button class="release-btn" click="release">Confirm</Button>
        </:action>
      </Modal>
    </div>
    """
  end
end
