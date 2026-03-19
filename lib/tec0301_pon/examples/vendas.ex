defmodule Tec0301Pon.Examples.Vendas do
  @moduledoc """
  PoC: **Sistema de Vendas** simplificado (Ferreira 2015, Santos 2017, Ronszcka 2019).

  Fatos: estoque disponível, cliente válido, tipo de desconto, quantidade do pedido.
  Regra 1: venda permitida se estoque >= quantidade e cliente válido.
  Regra 2: desconto especial se tipo em [:vip, :premium].

  Regras definidas via DSL em `Vendas.Regras`.
  Execute: mix run examples/vendas_simulacao.exs
  """
  alias Tec0301Pon.PON.Fato

  def start_link do
    Fato.start_link(:vendas_estoque, 10)
    Fato.start_link(:vendas_cliente_valido, false)
    Fato.start_link(:vendas_tipo_desconto, :normal)
    Fato.start_link(:vendas_quantidade_pedido, 0)
    Tec0301Pon.Examples.Vendas.Regras.RegraVendaPermitida.start_link()
    Tec0301Pon.Examples.Vendas.Regras.RegraDescontoEspecial.start_link()
    {:ok, self()}
  end

  def simular do
    IO.puts("--- Sistema de Vendas (PoC) ---")
    Process.sleep(400)

    IO.puts("\n[Pedido] Quantidade: 3.")
    Fato.atualizar(:vendas_quantidade_pedido, 3)
    Process.sleep(400)

    IO.puts("[Sistema] Cliente validado.")
    Fato.atualizar(:vendas_cliente_valido, true)
    Process.sleep(400)

    IO.puts("[Sistema] Tipo de cliente: vip.")
    Fato.atualizar(:vendas_tipo_desconto, :vip)
    Process.sleep(500)
  end
end
