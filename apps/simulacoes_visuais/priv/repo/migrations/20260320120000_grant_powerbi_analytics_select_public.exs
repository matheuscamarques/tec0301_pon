defmodule SimulacoesVisuais.Repo.Migrations.GrantPowerbiAnalyticsSelectPublic do
  @moduledoc """
  Reaplica SELECT em todas as tabelas/views do schema `public` para `powerbi_analytics`.
  Útil após novas migrations que criam `ml_predictions` ou outras relações sem
  `ALTER DEFAULT PRIVILEGES` cobrindo o owner correto.
  """
  use Ecto.Migration

  def up do
    execute """
    DO $$
    BEGIN
      IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powerbi_analytics') THEN
        EXECUTE 'GRANT SELECT ON ALL TABLES IN SCHEMA public TO powerbi_analytics';
      END IF;
    END $$;
    """
  end

  def down, do: :ok
end
