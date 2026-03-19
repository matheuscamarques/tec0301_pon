# Tec0301Pon

## Autor
Matheus de Camargo Marques - matheuscamarques@gmail.com

Prova de conceito do **Paradigma Orientado a Notificações (PON)** em Elixir/BEAM: núcleo com Fatos e Regras (GenServer + Registry), Ports & Adapters e DSL via metaprogramação.

### Documentação do projeto

| Onde | O que |
|------|--------|
| **`docs/artigos/`** | Artigos que descrevem a arquitetura e o passo a passo da implementação (motor PON, Estufa, DSL, Hot Swap). **Use como referência para entender e documentar o código.** |
| **`docs/recursos/`** | Recursos bibliográficos (teses, dissertações, textos sobre PON). Ver `docs/recursos/README.md` para o índice. **Servem de fundamentação teórica para os `@moduledoc` e o artigo.** |
| **Código** | `@moduledoc` e `@doc` nos módulos; gere a doc com `mix docs`. |

**Resumo:** Os artigos em `docs/artigos/` são a “documentação de design” do código; os recursos em `docs/recursos/` embasam a teoria. Para documentar o código, use os artigos como guia e cite conceitos (ou `docs/recursos/`) quando for explicar o PON no ExDoc.
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

