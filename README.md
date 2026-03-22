# TEC0301 - Tópicos Especiais em EC (Engenharia da Computação): Paradigma Orientado a Notificações

## Autor
Matheus de Camargo Marques - matheuscamarques@gmail.com

Prova de conceito do **Paradigma Orientado a Notificações (PON)** em Elixir/BEAM: núcleo com Fatos e Regras (GenServer + Registry), Ports & Adapters e DSL via metaprogramação.

### Repositório (GitHub)

O código-fonte público está em **[github.com/matheuscamarques/tec0301_pon](https://github.com/matheuscamarques/tec0301_pon)**. Detalhes e comando de clone: [`docs/repositorio-github.md`](docs/repositorio-github.md).

### Documentação do projeto

A documentação de design (artigos de arquitetura, passo a passo do motor PON, Estufa, DSL, Hot Swap) e os recursos bibliográficos (teses, dissertações, textos sobre PON) são mantidos em repositório sigiloso e não estão versionados aqui.

| Onde | O que |
|------|--------|
| **GitHub** | Repositório oficial: [matheuscamarques/tec0301_pon](https://github.com/matheuscamarques/tec0301_pon) — ver também [`docs/repositorio-github.md`](docs/repositorio-github.md). |
| **Código** | `@moduledoc` e `@doc` nos módulos; gere a doc com `mix docs`. |

**Comparação com o kernel NOP (outra implementação em Elixir):** neste repositório um **Fato** é um nome + valor e as atualizações propagam via `Registry.dispatch` por tópico; no NOP um **FBE** tem vários atributos e **links** explícitos para premissas. Aqui uma **Regra** agrega memória local, `avaliar` e `executar`; no NOP a cadeia é **Premise → Condition → Rule** com instigações. O barramento aqui é **Registry** (desacoplado por nome); no NOP são **cast** entre PIDs no grafo. Código de referência: `lib/tec0301_pon/pon/fato.ex`, `regra.ex`, `builder.ex`.

**Série dev.to (roteiro editorial, 12 partes em português)** — perfil: [dev.to/matheuscamarques](https://dev.to/matheuscamarques); roteiro e URLs dos posts: [`docs/devto_serie_pon_smart_brewery.md`](docs/devto_serie_pon_smart_brewery.md).

| Parte | Título |
|------:|--------|
| 1 | Paradigma Orientado a Notificações (PON) em Elixir: por que a BEAM é um bom lugar para regras reativas |
| 2 | Do papel ao código: mapeando Fatos, Regras e Premissas para processos OTP |
| 3 | DSL com metaprogramação: `defrule` e `defpremissa` para escrever menos boilerplate PON |
| 4 | Hexagonal + PON: Ports & Adapters para não acoplar o motor ao mundo real |
| 5 | Smart Brewery: um gêmeo digital cervejeiro como laboratório para o PON |
| 6 | Phoenix LiveView e tempo real: painel operacional sobre um motor de regras |
| 7 | Da simulação ao armazém: telemetria, Broadway/GenStage e TimescaleDB |
| 8 | BI sem mistério: dimensões, fatos e consumo dos dados (ex.: Power BI) |
| 9 | ML no gêmeo digital: exportar dados, treinar pilotos e importar predições de volta ao app |
| 10 | Quando as notificações explodem: message storm, deduplicação e padrões de back-pressure no PON |
| 11 | Profiling em produção dev: CPU, memória e o que mudou depois das otimizações |
| 12 | Retrospectiva: o que aprendi construindo um motor de regras reativo em Elixir |

Existe variante **enxuta em 6 posts** (fundindo pares da lista acima). Títulos em inglês seguem a mesma ordem (ex.: *Notification-Oriented Paradigm (PON) in Elixir…* na parte 1).

**Tags sugeridas no dev.to:** `elixir`, `phoenix`, `liveview`, `otp`, `machinelearning`, `timescaledb`; opcionais: `iot`, `industry40`, `architecture`, `functional`.

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

