defmodule Tec0301Pon.Examples.Vendas.Regras do
  @moduledoc """
  Regras do Sistema de Vendas definidas via DSL (PON.Builder).
  """
  use Tec0301Pon.PON.Builder

  defrule(RegraVendaPermitida,
    watch: [:vendas_estoque, :vendas_cliente_valido, :vendas_quantidade_pedido],
    when:
      (memoria[:vendas_quantidade_pedido] || 0) > 0 and memoria[:vendas_cliente_valido] == true and
        (memoria[:vendas_estoque] || 0) >= (memoria[:vendas_quantidade_pedido] || 0),
    do:
      (
        qty = memoria[:vendas_quantidade_pedido] || 0
        IO.puts("\n[Regra Vendas] Venda permitida: processando #{qty} unidade(s).")
      )
  )

  defrule(RegraDescontoEspecial,
    watch: [:vendas_tipo_desconto],
    when: (memoria[:vendas_tipo_desconto] || :normal) in [:vip, :premium],
    do:
      (
        t = memoria[:vendas_tipo_desconto] || :normal
        pct = if t == :premium, do: 15, else: 10
        IO.puts("\n[Regra Desconto] Cliente #{t}: aplicando #{pct}% de desconto.")
      )
  )
end
