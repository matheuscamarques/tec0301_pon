defmodule SimulacoesVisuaisWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use SimulacoesVisuaisWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  @doc """
  Renders your app layout.

  This function is typically invoked from every template,
  and it often contains your application menu, sidebar,
  or similar.

  ## Examples

      <Layouts.app flash={@flash}>
        <h1>Content</h1>
      </Layouts.app>

  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://hexdocs.pm/phoenix/scopes.html)"

  attr :wide, :boolean,
    default: false,
    doc: "when true, main content uses max-w-7xl (e.g. for SCADA panel)"

  attr :current_path, :string,
    default: nil,
    doc: "current request path for highlighting active nav link"

  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="navbar px-4 sm:px-6 lg:px-8 bg-base-100/95 backdrop-blur border-b border-base-200 min-h-14">
      <div class="flex-1">
        <a
          href="/"
          class="flex w-fit items-center gap-2 transition-opacity hover:opacity-90 focus-ring rounded"
        >
          <img src={~p"/images/logo.svg"} width="36" height="36" alt="TEC0301 PON" />
          <span class="text-sm font-semibold text-base-content">Gêmeo Digital</span>
        </a>
      </div>
      <nav class="flex-none" aria-label="Principal">
        <ul class="flex flex-row flex-wrap gap-1 sm:gap-2 items-center justify-end">
          <li>
            <a
              href="/"
              class={[
                "btn btn-ghost btn-sm rounded transition-colors focus-ring",
                @current_path == "/" && "btn-active"
              ]}
            >
              Início
            </a>
          </li>
          <li>
            <a
              href="/smart-brewery"
              class={[
                "btn btn-ghost btn-sm rounded transition-colors focus-ring",
                @current_path == "/smart-brewery" && "btn-active"
              ]}
            >
              Smart Brewery
            </a>
          </li>
          <li class="pl-2 border-l border-base-300">
            <.theme_toggle />
          </li>
        </ul>
      </nav>
    </header>

    <main class={["px-4 py-6 sm:px-6 lg:px-8", @wide && "py-4"]}>
      <div class={["mx-auto space-y-4", @wide && "max-w-7xl", !@wide && "max-w-2xl"]}>
        {render_slot(@inner_block)}
      </div>
    </main>

    <footer class="border-t border-base-200 py-3 px-4 sm:px-6 lg:px-8">
      <div class={[
        "mx-auto text-center text-xs text-base-content/60",
        @wide && "max-w-7xl",
        !@wide && "max-w-2xl"
      ]}>
        TEC0301 PON · Gêmeo Digital Smart Brewery · Simulações visuais
      </div>
    </footer>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end

  @theme_options [
    {"system", "hero-computer-desktop-micro", "Tema do sistema"},
    {"light", "hero-sun-micro", "Tema claro"},
    {"dark", "hero-moon-micro", "Tema escuro"}
  ]

  @doc """
  Provides dark vs light theme toggle based on themes defined in app.css.

  See <head> in root.html.heex which applies the theme before page load.
  """
  def theme_toggle(assigns) do
    assigns = assign(assigns, :theme_options, @theme_options)

    ~H"""
    <div class="card relative flex flex-row items-center border-2 border-base-300 bg-base-300 rounded-full">
      <div class="absolute w-1/3 h-full rounded-full border-1 border-base-200 bg-base-100 brightness-200 left-0 [[data-theme=light]_&]:left-1/3 [[data-theme=dark]_&]:left-2/3 transition-[left]" />

      <%= for {theme_id, icon, aria_label} <- @theme_options do %>
        <button
          type="button"
          class="flex p-2 cursor-pointer w-1/3 rounded-full transition-opacity focus-ring"
          phx-click={JS.dispatch("phx:set-theme")}
          data-phx-theme={theme_id}
          aria-label={aria_label}
        >
          <.icon name={icon} class="size-4 opacity-75 hover:opacity-100" />
        </button>
      <% end %>
    </div>
    """
  end
end
