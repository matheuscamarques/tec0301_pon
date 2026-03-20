defmodule SimulacoesVisuais.Repo.Migrations.AddPowerbiAnalyticsReadonlyRole do
  @moduledoc """
  Artigo 14: Role read-only para o Power BI (governança e segurança).
  O conector BI deve usar este usuário, sem direitos de administrador.

  Senha: defina POWERBI_ANALYTICS_PASSWORD antes de rodar a migration para
  evitar o placeholder. Em produção, rotacione com:
  ALTER ROLE powerbi_analytics WITH PASSWORD 'novo_token';
  """
  use Ecto.Migration

  def up do
    password = System.get_env("POWERBI_ANALYTICS_PASSWORD") || "change_me_in_production"
    # Aspas na senha: literal do 2º arg de format() no PostgreSQL
    escaped = String.replace(password, "'", "''")

    # Roles são globais ao cluster: após `ecto.drop` o DB some mas o role pode permanecer.
    execute """
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'powerbi_analytics') THEN
        EXECUTE format('CREATE ROLE powerbi_analytics WITH LOGIN PASSWORD %L', '#{escaped}');
      END IF;
    END $$;
    """

    execute """
    DO $$
    BEGIN
      EXECUTE 'GRANT CONNECT ON DATABASE ' || current_database() || ' TO powerbi_analytics';
    END $$;
    """

    execute "GRANT USAGE ON SCHEMA public TO powerbi_analytics;"
    execute "GRANT SELECT ON ALL TABLES IN SCHEMA public TO powerbi_analytics;"
    execute "ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO powerbi_analytics;"
  end

  def down do
    execute "REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM powerbi_analytics;"
    execute "REVOKE USAGE ON SCHEMA public FROM powerbi_analytics;"
    execute """
    DO $$
    BEGIN
      EXECUTE 'REVOKE CONNECT ON DATABASE ' || current_database() || ' FROM powerbi_analytics';
    END $$;
    """
    execute "DROP ROLE IF EXISTS powerbi_analytics;"
  end
end
