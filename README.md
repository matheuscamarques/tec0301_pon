# TEC0301 - Tópicos Especiais em EC (Engenharia da Computação): Paradigma Orientado a Notificações

## Autor
Matheus de Camargo Marques - matheuscamarques@gmail.com

Prova de conceito do **Paradigma Orientado a Notificações (PON)** em Elixir/BEAM: núcleo com Fatos e Regras (GenServer + Registry), Ports & Adapters e DSL via metaprogramação.

### Documentação do projeto

A documentação de design (artigos de arquitetura, passo a passo do motor PON, Estufa, DSL, Hot Swap) e os recursos bibliográficos (teses, dissertações, textos sobre PON) são mantidos em repositório sigiloso e não estão versionados aqui.

| Onde | O que |
|------|--------|
| **Código** | `@moduledoc` e `@doc` nos módulos; gere a doc com `mix docs`. |
| **Comparação NOP** | [docs/comparison_pon_vs_nop_kernel.md](docs/comparison_pon_vs_nop_kernel.md) e recursos incorporados. |

Use o código e a documentação gerada com `mix docs` como referência principal para entender e estender o PON.

### DSL PON (Builder)

O núcleo expõe uma DSL em `use Tec0301Pon.PON.Builder`:

- **defrule** – Define uma regra: `watch:` (fatos), `when:` (condição em código ou em string) e `do:` (ação em bloco ou `instigations: [{Mod, :fun, [args]}, ...]`). Gera um submódulo com `avaliar/1`, `executar/1` e `start_link/0`.
- **defpremissa** – Define uma premissa reutilizável (estilo NOP): observa fatos em `watch:`, avalia `when:` e atualiza o fato em `derive:` apenas quando o resultado booleano muda. Opção `criar_fato: true` cria o fato derivado se não existir. Regras podem então observar o fato derivado em vez de repetir a condição.

Exemplo combinado:

```elixir
defmodule MeuApp.Regras do
  use Tec0301Pon.PON.Builder

  defpremissa TempAlta,
    watch: [:temp_ambiente],
    when: (memoria[:temp_ambiente] || 0) > 30,
    derive: :temp_alta,
    criar_fato: true

  defrule RegraRefrigera,
    watch: [:temp_alta, :estado_compressor],
    when: memoria[:temp_alta] == true and memoria[:estado_compressor] == :off,
    do: MeuApp.Atuadores.ligar_compressor()
end
```

No bootstrap: iniciar fatos, depois `MeuApp.Regras.TempAlta.start_link()` (premissa), depois as regras (e.g. `MeuApp.Regras.RegraRefrigera.start_link()`). Estatísticas opcionais via `Tec0301Pon.PON.Service` (ver `Tec0301Pon.PON.Service` e `Tec0301Pon.PON.Fato.estatisticas/1`).
## Uma Abordagem Funcional e Dinâmica para o Paradigma Orientado a Notificações: Metaprogramação, Arquitetura Hexagonal e Troca Quente de Código em Elixir

### 1. Problema e Justificativa
O PON propõe uma arquitetura descentralizada, reativa e orientada a eventos para avaliação de regras e tomada de decisão. No entanto, a implementação do PON em linguagens orientadas a objetos tradicionais muitas vezes gera um alto acoplamento ou boilerplate excessivo (criação manual de Fatos, Regras, Premissas e Ações).

A linguagem Elixir, rodando na BEAM, oferece concorrência nativa (atores como Fatos e Regras comunicando-se por mensagens/notificações). A metaprogramação permite abstrair a complexidade de criação das entidades do PON, gerando código em tempo de compilação. A Arquitetura Hexagonal (Ports & Adapters) garante que as notificações do núcleo PON possam interagir com interfaces externas de forma limpa. Por fim, o Hot Code Swapping permite atualizar as regras do PON dinamicamente, mantendo o estado (Base de Fatos) intact.

### 2. Objetivos
**Objetivo Geral:**
Desenvolver um framework ou prova de conceito (PoC) baseada no Paradigma Orientado a Notificações em Elixir, utilizando metaprogramação para geração de entidades PON, estruturado em Ports & Adapters e capaz de atualizar suas regras em tempo de execução via Hot Code Swapping.

**Objetivos Específicos:**
- Mapear as entidades estruturais do PON (Fatos, Regras, Premissas, Condições e Ações) para processos da BEAM (ex: GenServer ou Agent).
### 3. Fundamentação Teórica (Revisão Bibliográfica)
Para compor o artigo, você precisará embasar as seguintes áreas:
- Paradigma Orientado a Notificações (PON): Conceitos de Causalidade, Entidades do PON, e como as notificações fluem para evitar avaliações redundantes (biliografia de J.M. Simão e pesquisadores associados).
### 4. Arquitetura Proposta do Projeto
Para facilitar a visualização da pesquisa, seu projeto pode ser dividido nas seguintes camadas:
- **Core (Motor PON):** Processos que guardam estados (Fatos) e processos que avaliam lógica (Regras). Quando um Fato muda, ele envia uma mensagem (notificação) para a Regra inscrita.
  - *Outbound Adapters:* Quando uma "Ação" do PON é acionada, ela chama uma porta que envia um email, salva no banco ou liga um hardware.

### 5. Metodologia de Desenvolvimento (Fases)
**Fase 1: Mapeamento PON-BEAM (Semanas 1-2)**
- Desenho no papel/diagrama de como um Fato notifica uma Regra usando processos OTP (GenServer, Registry para pub/sub local).
**Fase 2: Construção do Core e Hexagonal (Semanas 3-4)**
- Implementação manual (sem metaprogramação) de uma pequena malha do PON.
**Fase 3: A Magia das Macros (Semanas 5-6)**
- Criação das macros para injetar a estrutura definida na Fase 2 de forma automática. O foco é reduzir o código que o usuário final do seu framework precisa escrever.
**Fase 4: Prova de Fogo - Hot Code Swapping (Semanas 7-8)**
- Geração de uma release.
**Fase 5: Coleta de Métricas e Escrita do Artigo (Semanas 9-10)**
- Coletar dados de performance (tempo de resposta, latência de notificação) e consumo de memória.
### 6. Resultados Esperados
O artigo deverá provar que a união dessas tecnologias elimina dois dos maiores gargalos do PON: a curva de aprendizado para codificar a estrutura do PON (resolvido pela metaprogramação/DSL) e o tempo de inatividade para atualização de regras vitais de negócio (resolvido pelo Hot Code Swapping).

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `tec0301_pon` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:tec0301_pon, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/tec0301_pon>.

