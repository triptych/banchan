defmodule BanchanWeb.ReportBugLive.New do
  @moduledoc """
  Lets users submit GitHub bugs without having GitHub accounts themselves.
  """
  use BanchanWeb, :surface_view

  alias Banchan.Reports

  alias Surface.Components.Form

  alias BanchanWeb.Components.{Button, Layout}
  alias BanchanWeb.Components.Form.{MarkdownInput, Submit, TextInput}

  @impl true
  def handle_params(_params, uri, socket) do
    {:noreply, assign(socket, uri: uri, report_url: nil)}
  end

  @impl true
  def handle_event("submit", %{"bug_report" => %{"title" => title, "body" => body}}, socket) do
    case Reports.report_bug(
           socket.assigns.current_user,
           title,
           body,
           &Routes.denizen_show_url(Endpoint, :show, &1.handle)
         ) do
      {:ok, url} ->
        {:noreply, socket |> assign(report_url: url)}

      {:error, :internal_error} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "An internal error occurred while trying to file this bug report. Try again later, or email us at support@banchan.art."
         )}
    end
  end

  def handle_event("reset", _, socket) do
    {:noreply, socket |> assign(report_url: nil)}
  end

  @impl true
  def render(assigns) do
    ~F"""
    <Layout uri={@uri} padding={0} current_user={@current_user} flashes={@flash}>
      <div class="w-full md:bg-base-300">
        <div class="max-w-lg w-full rounded-xl p-10 mx-auto md:my-10 bg-base-100">
          {#if @report_url}
            <p>Thanks for your bug report! You can view the issue and sign up for updates <a href={@report_url} class="link link-primary">here</a>.</p>
            <Button label="Report Another" click="reset" />
          {#else}
            <Form class="flex flex-col gap-4" for={:bug_report} submit="submit">
              <h1 class="text-2xl">Submit a bug report</h1>
              <p>Use this form to submit bug reports for Banchan Art. Please include as much context as you can.</p>
              <p><span class="text-error">NOTE: This report will be <span class="font-bold">publicly visible</span> on GitHub. Do NOT include anything personal or confidential</span></p>
              <p>If you need support for something that shouldn't be public, please contact us at <a href="mailto:support@banchan.art" class="link">support@banchan.art</a>.</p>
              <TextInput name={:title} label="Title" opts={required: true, maxlength: "256", minlength: "10"} />
              <MarkdownInput
                id="body-input"
                name={:body}
                label="Body"
                opts={required: true, maxlength: "2000", minlength: "30"}
              />
              <Submit />
            </Form>
          {/if}
        </div>
      </div>
    </Layout>
    """
  end
end
