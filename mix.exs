defmodule Banchan.MixProject do
  use Mix.Project

  def project do
    [
      app: :banchan,
      version: "0.1.0",
      elixir: "~> 1.7",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [warnings_as_errors: true],
      compilers: [:phoenix, :gettext] ++ Mix.compilers() ++ [:surface],
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      test_coverage: [tool: ExCoveralls],
      preferred_cli_env: [
        quality: :test,
        "quality.ci": :test,
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test,
        "coveralls.github": :test
      ],
      dialyzer: [
        plt_ignore_apps: [:mnesia],
        ignore_warnings: ".dialyzer_ignores.exs"
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Banchan.Application, []},
      extra_applications: [:logger, :runtime_tools, :os_mon, :crypto]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"] ++ catalogues()
  defp elixirc_paths(:dev), do: ["lib"] ++ catalogues()
  defp elixirc_paths(_), do: ["lib"]

  def catalogues do
    [
      "priv/catalogue"
    ]
  end

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:bamboo, "~> 2.2.0"},
      {:bamboo_phoenix, "~> 1.0.0"},
      {:csv, "~> 2.5"},
      {:earmark, "~> 1.4.20"},
      {:ecto_psql_extras, "~> 0.7.4"},
      {:ecto_sql, "~> 3.8.3"},
      {:ex_aws_s3, "~> 2.3.2"},
      {:ex_aws, "~> 2.3.1"},
      {:ffmpex, "~> 0.10.0"},
      {:gettext, "~> 0.11"},
      {:hackney, "~> 1.18"},
      {:html_sanitize_ex, "~> 1.4.2"},
      {:httpoison, "~> 1.8.1"},
      {:jason, "~> 1.0"},
      # TODO: move back to mainline after
      # https://github.com/elixir-mogrify/mogrify/pull/112 is merged and
      # released.
      {:mogrify, github: "BanchanArt/mogrify"},
      {:money, "~> 1.9"},
      {:nimble_totp, "~> 0.1.0"},
      {:number, "~> 1.0.3"},
      {:oban, "~> 2.13"},
      {:pbkdf2_elixir, "~> 1.0"},
      {:phoenix_ecto, "~> 4.4"},
      {:phoenix_html, "~> 3.2.0"},
      {:phoenix_live_dashboard, "~> 0.6.5"},
      {:phoenix_live_view, "~> 0.17.11"},
      {:phoenix, "~> 1.6.12"},
      {:plug_cowboy, "~> 2.5.2"},
      {:postgrex, "~> 0.16.3"},
      {:qr_code, "~> 2.2.1"},
      {:scrivener_ecto, "~> 2.7.0"},
      {:sentry, "~> 8.0"},
      {:slugify, "~> 1.3.1"},
      {:stripity_stripe, "~> 2.15.0"},
      {:surface, "~> 0.8.2"},
      {:surface_catalogue, "~> 0.5.1"},
      {:surface_markdown, "~> 0.5.0"},
      {:sweet_xml, "~> 0.6"},
      {:telemetry_metrics, "~> 0.6"},
      {:telemetry_poller, "~> 0.5"},
      {:tentacat, "~> 2.2"},
      {:timex, "~> 3.7.6"},
      {:ueberauth_discord, "~> 0.7.0"},
      {:ueberauth_google, "~> 0.10.1"},
      {:ueberauth_twitter, "~> 0.4.1"},
      {:ueberauth, "~> 0.7"},
      {:uuid, "~> 1.1"},

      # Dev/test deps
      {:credo, "~> 1.5", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.1", only: [:dev, :test], runtime: false},
      {:esbuild, "~> 0.4", runtime: Mix.env() == :dev},
      {:excoveralls, "~> 0.13", only: :test},
      {:floki, "~> 0.33.0", only: :test},
      {:mox, "~> 1.0.1", only: :test},
      {:phoenix_live_reload, "~> 1.3.3", only: :dev},
      {:sobelow, "~> 0.8", only: [:dev, :test], runtime: false},
      {:surface_formatter, "~> 0.7.5", only: :dev}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup", "cmd npm install --prefix assets"],
      "deploy.dev": [
        "cmd fly deploy -a banchan-dev --build-arg BANCHAN_HOST=dev.banchan.art --build-arg BANCHAN_DEPLOY_ENV=dev"
      ],
      "deploy.prod": [
        "cmd fly deploy -a banchan-prod --build-arg BANCHAN_HOST=banchan.art --build-arg BANCHAN_DEPLOY_ENV=prod"
      ],
      "stripe.local": [
        "cmd stripe listen --forward-to localhost:4000/api/stripe_webhook"
      ],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      "assets.deploy": [
        "cmd --cd assets npm install",
        "cmd --cd assets npm run deploy:css",
        "esbuild default --minify",
        "phx.digest"
      ],
      reset: [
        "deps.get",
        "cmd --cd assets npm install",
        "ecto.reset"
      ],
      fmt: ["format"],
      test: [
        "ecto.drop --quiet",
        "ecto.create --quiet",
        "ecto.migrate --quiet",
        "run priv/repo/seeds.exs",
        "test"
      ],
      quality: [
        "compile --all-warnings --warnings-as-errors",
        "test",
        "format",
        "credo --strict",
        "sobelow --verbose"
        # ,
        # "dialyzer --ignore-exit-status"
      ]
    ]
  end
end
