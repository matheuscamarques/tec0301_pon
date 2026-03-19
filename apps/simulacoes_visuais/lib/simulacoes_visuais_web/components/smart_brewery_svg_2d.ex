defmodule SimulacoesVisuaisWeb.Components.SmartBrewerySvg2D do
  @moduledoc """
  Componente que renderiza o SVG integrado da Smart Brewery (2D) com telemetria
  bindada a @svg_values e phx-click por FBE para seleção no LiveView.
  """
  use Phoenix.Component

  attr :svg_values, :map, required: true, doc: "Mapa id => valor (ex: \"val-rpm\" => \"1025\")"
  attr :selected_fbe, :integer, default: nil, doc: "FBE id selecionado para highlight"

  attr :animation_style, :string,
    default: "",
    doc:
      "CSS custom properties (--speed-factor, --conveyor-speed) para animações reagirem ao estado"

  def svg_2d(assigns) do
    ~H"""
    <div
      class="relative flex justify-center bg-slate-950 rounded-xl overflow-x-auto border border-slate-700 custom-scrollbar svg-2d-container"
      style={@animation_style}
    >
      <svg
        width="1400"
        height="850"
        viewBox="0 0 1400 850"
        xmlns="http://www.w3.org/2000/svg"
        class="min-w-[1400px]"
        aria-label="Vista 2D Smart Brewery"
      >
        <defs>
          <linearGradient id="metal" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stop-color="#475569" />
            <stop offset="50%" stop-color="#94a3b8" />
            <stop offset="100%" stop-color="#475569" />
          </linearGradient>
          <linearGradient id="metal-dark" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stop-color="#1e293b" />
            <stop offset="50%" stop-color="#475569" />
            <stop offset="100%" stop-color="#1e293b" />
          </linearGradient>
          <linearGradient id="copper" x1="0%" y1="0%" x2="100%" y2="0%">
            <stop offset="0%" stop-color="#92400e" />
            <stop offset="50%" stop-color="#d97706" />
            <stop offset="100%" stop-color="#92400e" />
          </linearGradient>
          <pattern id="grid" width="40" height="40" patternUnits="userSpaceOnUse">
            <path d="M 40 0 L 0 0 0 40" fill="none" stroke="#334155" stroke-width="0.5" opacity="0.3" />
          </pattern>
          <g id="bottle">
            <path
              d="M 0 30 L 0 10 L 3 5 L 3 0 L 7 0 L 7 5 L 10 10 L 10 30 Z"
              fill="#92400e"
              stroke="#78350f"
              stroke-width="0.5"
            />
            <rect x="1" y="15" width="8" height="8" fill="#fbbf24" />
            <rect x="3" y="0" width="4" height="2" fill="#fbbf24" />
          </g>
        </defs>
        <rect width="100%" height="100%" fill="url(#grid)" />
        <rect x="0" y="780" width="1400" height="70" fill="#0f172a" />
        <%!-- Rede elétrica: linha em y=50, ramais até topo de cada equipamento --%>
        <path
          d="M 95 50 L 1232 50 M 95 50 L 95 135 M 330 50 L 330 185 M 525 50 L 525 185 M 705 50 L 705 185 M 877 50 L 877 288 M 977 50 L 977 135 M 1143 50 L 1143 135 M 1232 50 L 1232 62 M 95 50 L 95 660 L 165 660"
          class="path-power"
          stroke-width="2"
          fill="none"
          opacity="0.6"
        />
        <%!-- Grão: Moinho (1) -> Mostura (2) --%>
        <path
          d="M 155 275 L 155 295 L 260 295 L 330 295 L 330 185"
          class="path-grain"
          stroke-width="4"
          fill="none"
        />
        <%!-- Mosto quente: Mostura (2) -> Tina (3) --%>
        <path
          d="M 390 295 L 440 295 L 525 295 L 525 185"
          class="path-hot"
          stroke-width="4"
          fill="none"
        />
        <%!-- Mosto quente: Tina (3) -> Fervura (4) --%>
        <path
          d="M 590 295 L 625 295 L 705 295 L 705 185"
          class="path-hot"
          stroke-width="4"
          fill="none"
        />
        <%!-- Mosto quente: Fervura (4) -> Trocador (5) --%>
        <path
          d="M 765 395 L 840 395 L 877 395 L 877 288"
          class="path-hot"
          stroke-width="4"
          fill="none"
        />
        <%!-- Frio: Trocador (5) -> Ferm. A (6) --%>
        <path
          d="M 922 388 L 950 388 L 977 388 L 977 135"
          class="path-cold"
          stroke-width="4"
          fill="none"
        />
        <%!-- Frio: Ferm. A (6) -> Ferm. B (7) --%>
        <path
          d="M 1022 245 L 1143 245 L 1143 135"
          class="path-cold"
          stroke-width="4"
          fill="none"
        />
        <%!-- Frio: Ferm. B (7) -> zona envase --%>
        <path
          d="M 1143 355 L 1143 440 L 1050 440 L 1050 505 L 950 505 L 950 545"
          class="path-cold"
          stroke-width="4"
          fill="none"
        />
        <%!-- CIP: Sistema CIP (9) -> Linha Envase (8) e ramais para tanques --%>
        <path
          d="M 365 651 L 613 651 L 613 535 M 613 535 L 613 205 L 330 205 L 330 185 M 613 205 L 525 205 L 525 185 M 613 205 L 705 205 L 705 185 M 613 205 L 788 205 L 788 255 M 613 205 L 938 205 L 977 135 M 613 205 L 1040 205 L 1143 135"
          class="path-cip"
          stroke-width="3"
          fill="none"
          opacity="0.8"
        />

        <%!-- 11. SMART GRID --%>
        <g
          transform="translate(1142, 72)"
          class={group_class(@selected_fbe, 11)}
          phx-click="select_fbe_2d"
          phx-value-id="11"
          role="button"
          tabindex="0"
        >
          <rect
            x="-10"
            y="-10"
            width="180"
            height="120"
            rx="8"
            fill="#1e293b"
            opacity="0.9"
            stroke="#3b82f6"
            stroke-width="1"
          />
          <circle cx="160" cy="5" r="3" fill="#22c55e" class="live-led" />
          <text x="10" y="10" class="eq-title">11. SMART GRID</text>
          <line x1="30" y1="80" x2="30" y2="40" stroke="#94a3b8" stroke-width="3" />
          <g transform="translate(30, 40)" class="spin-slow">
            <path
              d="M0 0 L-5 -25 L5 -25 Z M0 0 L20 15 L15 20 Z M0 0 L-20 15 L-15 20 Z"
              fill="#cbd5e1"
            />
          </g>
          <rect
            x="50"
            y="60"
            width="40"
            height="20"
            fill="#1d4ed8"
            stroke="#60a5fa"
            transform="skewX(-20)"
          />
          <rect x="100" y="50" width="30" height="30" rx="2" fill="#334155" stroke="#475569" />
          <rect x="105" y="65" width="20" height="10" fill="#22c55e" />
          <circle cx="115" cy="58" r="2" fill="#22c55e" class="spin-fast" stroke-dasharray="2,2" />
          <rect x="10" y="95" width="160" height="10" fill="transparent" />
          <text x="10" y="100" class="data-label">
            Load:
            <tspan id="val-load" class="data-value">{Map.get(@svg_values, "val-load", "-")}</tspan>
            kW | Cost:
            <tspan id="val-cost" class="data-value">{Map.get(@svg_values, "val-cost", "-")}</tspan>
            ¢
          </text>
        </g>

        <%!-- 01. MOINHO --%>
        <g
          transform="translate(95, 145)"
          class={group_class(@selected_fbe, 1)}
          phx-click="select_fbe_2d"
          phx-value-id="1"
          role="button"
          tabindex="0"
        >
          <rect x="-10" y="-10" width="140" height="140" rx="8" fill="#1e293b" opacity="0.9" />
          <circle cx="120" cy="5" r="3" fill="#22c55e" class="live-led" />
          <text x="10" y="10" class="eq-title">01. MOINHO</text>
          <g transform="translate(70, 40)">
            <circle
              cx="0"
              cy="0"
              r="1.5"
              fill="#fcd34d"
              class="grain-particle"
              style="animation-delay: 0s;"
            />
            <circle
              cx="-5"
              cy="0"
              r="1.5"
              fill="#d97706"
              class="grain-particle"
              style="animation-delay: 0.2s;"
            />
            <circle
              cx="5"
              cy="0"
              r="1.5"
              fill="#fcd34d"
              class="grain-particle"
              style="animation-delay: 0.4s;"
            />
          </g>
          <path d="M40 30 L100 30 L80 80 L60 80 Z" fill="url(#metal)" opacity="0.9" />
          <rect x="50" y="80" width="40" height="40" rx="2" fill="#334155" stroke="#475569" />
          <g
            transform="translate(50, 80)"
            class="liquid-level-hopper"
            style="transform-origin: 20px 40px;"
          >
            <rect width="40" height="40" rx="2" fill="#d97706" opacity="0.75" />
          </g>
          <circle
            cx="60"
            cy="100"
            r="8"
            fill="#1e293b"
            class="spin-fast"
            stroke-dasharray="2,2"
            stroke="#94a3b8"
          />
          <circle
            cx="80"
            cy="100"
            r="8"
            fill="#1e293b"
            class="spin-rev-fast"
            stroke-dasharray="2,2"
            stroke="#94a3b8"
          />
          <rect x="0" y="130" width="140" height="40" fill="#0f172a" rx="4" />
          <text x="5" y="145" class="data-label">
            RPM:
            <tspan id="val-rpm" class="data-value">{Map.get(@svg_values, "val-rpm", "-")}</tspan>
          </text>
          <text x="5" y="160" class="data-label">
            Vibração:
            <tspan id="val-vib" class="data-value">{Map.get(@svg_values, "val-vib", "-")}</tspan>
            | Lvl:
            <tspan id="val-hop">{Map.get(@svg_values, "val-hop", "-")}</tspan>
          </text>
        </g>

        <%!-- 02. MOSTURA --%>
        <g
          transform="translate(260, 195)"
          class={group_class(@selected_fbe, 2)}
          phx-click="select_fbe_2d"
          phx-value-id="2"
          role="button"
          tabindex="0"
        >
          <rect x="-10" y="-10" width="140" height="200" rx="8" fill="#1e293b" opacity="0.9" />
          <circle cx="120" cy="5" r="3" fill="#22c55e" class="live-led" />
          <text x="10" y="10" class="eq-title">02. MOSTURA</text>
          <path
            d="M30 40 Q30 30 70 30 Q110 30 110 40 L110 150 Q110 160 70 160 Q30 160 30 150 Z"
            fill="url(#copper)"
            stroke="#b45309"
            stroke-width="2"
          />
          <g class="liquid-level-mostura" style="transform-origin: 70px 150px;">
            <rect x="35" y="70" width="70" height="80" fill="#78350f" class="liquid-anim" />
          </g>
          <line x1="70" y1="30" x2="70" y2="130" stroke="#1e293b" stroke-width="2" />
          <g class="spin-fast" transform="translate(70, 120)">
            <line x1="-20" y1="0" x2="20" y2="0" stroke="#1e293b" stroke-width="3" />
          </g>
          <circle cx="70" cy="20" r="8" fill="#22c55e" />
          <rect x="0" y="190" width="140" height="40" fill="#0f172a" rx="4" />
          <text x="5" y="205" class="data-label">
            Temp: <tspan id="val-mash-temp" class="data-value"><%= Map.get(@svg_values, "val-mash-temp", "-") %></tspan>°C (Mash)
          </text>
          <text x="5" y="220" class="data-label">
            Flow:
            <tspan id="val-flow" class="data-value">{Map.get(@svg_values, "val-flow", "-")}</tspan>
            | Agit: ON
          </text>
        </g>

        <%!-- 03. TINA DE FILTRO --%>
        <g
          transform="translate(450, 195)"
          class={group_class(@selected_fbe, 3)}
          phx-click="select_fbe_2d"
          phx-value-id="3"
          role="button"
          tabindex="0"
        >
          <rect x="-10" y="-10" width="150" height="200" rx="8" fill="#1e293b" opacity="0.9" />
          <circle cx="130" cy="5" r="3" fill="#22c55e" class="live-led" />
          <text x="10" y="10" class="eq-title">03. TINA DE FILTRO</text>
          <path
            d="M20 50 Q20 40 70 40 Q120 40 120 50 L120 150 Q120 160 70 160 Q20 160 20 150 Z"
            fill="url(#metal)"
          />
          <line
            x1="25"
            y1="130"
            x2="115"
            y2="130"
            stroke="#1e293b"
            stroke-dasharray="2,2"
            stroke-width="2"
          />
          <rect x="25" y="80" width="90" height="50" fill="#d97706" opacity="0.5" />
          <rect
            x="25"
            y="135"
            width="90"
            height="20"
            fill="#f59e0b"
            class="liquid-anim"
            opacity="0.8"
          />
          <g class="spin-slow" transform="translate(70, 110)">
            <line x1="-30" y1="0" x2="30" y2="0" stroke="#1e293b" stroke-width="2" />
            <line x1="-20" y1="0" x2="-20" y2="15" stroke="#1e293b" stroke-width="1" />
            <line x1="20" y1="0" x2="20" y2="15" stroke="#1e293b" stroke-width="1" />
          </g>
          <line x1="70" y1="30" x2="70" y2="110" stroke="#1e293b" stroke-width="2" />
          <circle cx="70" cy="20" r="8" fill="#22c55e" />
          <rect x="0" y="190" width="150" height="40" fill="#0f172a" rx="4" />
          <text x="5" y="205" class="data-label">
            Diff Press:
            <tspan id="val-press" class="data-value">{Map.get(@svg_values, "val-press", "-")}</tspan>
          </text>
          <text x="5" y="220" class="data-label">
            Pump:
            <tspan id="val-pump" class="data-value">{Map.get(@svg_values, "val-pump", "-")}</tspan>
            | Rake: 43
          </text>
        </g>

        <%!-- 04. FERVURA --%>
        <g
          transform="translate(635, 195)"
          class={group_class(@selected_fbe, 4)}
          phx-click="select_fbe_2d"
          phx-value-id="4"
          role="button"
          tabindex="0"
        >
          <rect x="-10" y="-10" width="140" height="200" rx="8" fill="#1e293b" opacity="0.9" />
          <circle cx="120" cy="5" r="3" fill="#22c55e" class="live-led" />
          <text x="10" y="10" class="eq-title">04. FERVURA</text>
          <g class="steam" transform="translate(70, 20)">
            <circle cx="0" cy="0" r="12" fill="#f1f5f9" opacity="0.6" />
            <circle cx="-10" cy="10" r="10" fill="#e2e8f0" opacity="0.5" />
          </g>
          <path
            d="M30 60 Q30 30 70 30 Q110 30 110 60 L110 150 Q110 160 70 160 Q30 160 30 150 Z"
            fill="url(#metal)"
            stroke="#475569"
            stroke-width="2"
          />
          <rect x="35" y="70" width="70" height="85" fill="#dc2626" class="liquid-anim" />
          <g class="foam-level" transform="translate(70, 150)">
            <circle cx="-15" cy="-10" r="4" fill="#fca5a5" class="bubble" style="animation-delay: 0s" />
            <circle cx="10" cy="-5" r="3" fill="#fca5a5" class="bubble" style="animation-delay: 0.4s" />
            <circle
              cx="20"
              cy="-20"
              r="5"
              fill="#fca5a5"
              class="bubble"
              style="animation-delay: 0.8s"
            />
            <circle
              cx="-5"
              cy="-30"
              r="3"
              fill="#fca5a5"
              class="bubble"
              style="animation-delay: 1.2s"
            />
          </g>
          <rect x="60" y="10" width="20" height="20" fill="#334155" />
          <rect x="40" y="155" width="60" height="10" fill="#ea580c" />
          <rect x="45" y="155" width="50" height="8" fill="#fbbf24" class="fire-glow" />
          <rect x="0" y="190" width="140" height="40" fill="#0f172a" rx="4" />
          <text x="5" y="205" class="data-label">
            Temp: <tspan id="val-boil-temp" class="data-value"><%= Map.get(@svg_values, "val-boil-temp", "-") %></tspan>°C (Boil)
          </text>
          <text x="5" y="220" class="data-label">
            Evap: <tspan id="val-evap" class="data-value"><%= Map.get(@svg_values, "val-evap", "-") %></tspan>% | Foam: 65
          </text>
        </g>

        <%!-- 05. TROCADOR --%>
        <g
          transform="translate(822, 298)"
          class={group_class(@selected_fbe, 5)}
          phx-click="select_fbe_2d"
          phx-value-id="5"
          role="button"
          tabindex="0"
        >
          <rect x="-10" y="-10" width="110" height="100" rx="8" fill="#1e293b" opacity="0.9" />
          <text x="5" y="10" class="eq-title">05. TROCADOR</text>
          <rect x="20" y="25" width="50" height="40" fill="#64748b" />
          <line x1="30" y1="25" x2="30" y2="65" stroke="#1e293b" />
          <line x1="40" y1="25" x2="40" y2="65" stroke="#1e293b" />
          <line x1="50" y1="25" x2="50" y2="65" stroke="#1e293b" />
          <line x1="60" y1="25" x2="60" y2="65" stroke="#1e293b" />
          <path
            d="M25 45 L65 45"
            stroke="#ef4444"
            stroke-width="4"
            stroke-dasharray="4,2"
            class="conveyor-run"
            opacity="0.7"
          />
          <path
            d="M65 55 L25 55"
            stroke="#3b82f6"
            stroke-width="4"
            stroke-dasharray="4,2"
            class="conveyor-run"
            opacity="0.7"
          />
          <rect x="0" y="90" width="110" height="30" fill="#0f172a" rx="4" />
          <text x="5" y="102" class="data-label">
            In:
            <tspan id="val-heat-in">{Map.get(@svg_values, "val-heat-in", "-")}</tspan>
            Out: <tspan id="val-heat-out" class="data-value"><%= Map.get(@svg_values, "val-heat-out", "-") %></tspan>°C
          </text>
          <text x="5" y="115" class="data-label">Glycol Válvula: 25%</text>
        </g>

        <%!-- 06. FERM. A --%>
        <g
          transform="translate(922, 145)"
          class={group_class(@selected_fbe, 6)}
          phx-click="select_fbe_2d"
          phx-value-id="6"
          role="button"
          tabindex="0"
        >
          <rect x="-10" y="-10" width="110" height="210" rx="8" fill="#1e293b" opacity="0.9" />
          <circle cx="90" cy="5" r="3" fill="#22c55e" class="live-led" />
          <text x="10" y="10" class="eq-title">06. FERM. A</text>
          <path
            d="M20 40 Q20 30 50 30 Q80 30 80 40 L80 120 L50 160 L20 120 Z"
            fill="url(#metal-dark)"
            stroke="#64748b"
            stroke-width="2"
          />
          <path
            d="M25 70 L75 70 L75 118 L50 152 L25 118 Z"
            fill="#b45309"
            class="liquid-anim"
            opacity="0.6"
          />
          <g transform="translate(50, 150)">
            <circle cx="-10" cy="0" r="2" fill="#fff" class="co2" style="animation-delay: 0s;" />
            <circle cx="15" cy="-20" r="1.5" fill="#fff" class="co2" style="animation-delay: 0.6s;" />
            <circle cx="5" cy="-40" r="2.5" fill="#fff" class="co2" style="animation-delay: 1.2s;" />
          </g>
          <path
            d="M25 50 L75 50 L75 100 L25 100 Z"
            fill="transparent"
            stroke="#ef4444"
            stroke-width="1"
            stroke-dasharray="2,2"
          />
          <rect x="0" y="200" width="110" height="40" fill="#0f172a" rx="4" />
          <text x="5" y="215" class="data-label">
            Temp: <tspan id="val-ferm-a" class="data-value"><%= Map.get(@svg_values, "val-ferm-a", "-") %></tspan>°C | Bx: 25
          </text>
          <text x="5" y="230" class="data-label">
            Fase:
            <tspan class="data-value">LAG</tspan>
            (Jacket OFF)
          </text>
        </g>

        <%!-- 07. FERM. B --%>
        <g
          transform="translate(1088, 145)"
          class={group_class(@selected_fbe, 7)}
          phx-click="select_fbe_2d"
          phx-value-id="7"
          role="button"
          tabindex="0"
        >
          <rect x="-10" y="-10" width="110" height="210" rx="8" fill="#1e293b" opacity="0.9" />
          <circle cx="90" cy="5" r="3" fill="#22c55e" class="live-led" />
          <text x="10" y="10" class="eq-title">07. FERM. B (BRITE)</text>
          <path
            d="M20 40 Q20 30 50 30 Q80 30 80 40 L80 140 Q80 160 50 160 Q20 160 20 140 Z"
            fill="url(#metal-dark)"
            stroke="#64748b"
            stroke-width="2"
          />
          <path
            d="M25 60 L75 60 L75 140 Q75 155 50 155 Q25 155 25 140 Z"
            fill="#fbbf24"
            class="liquid-anim"
            opacity="0.6"
          />
          <g transform="translate(50, 150)">
            <circle cx="0" cy="0" r="1" fill="#fff" class="co2" style="animation-delay: 0.2s;" />
            <circle cx="-15" cy="-30" r="1.5" fill="#fff" class="co2" style="animation-delay: 1.5s;" />
          </g>
          <path
            d="M25 50 L75 50 L75 100 L25 100 Z"
            fill="#3b82f6"
            opacity="0.2"
            stroke="#3b82f6"
            stroke-width="1"
            stroke-dasharray="2,2"
          />
          <rect x="0" y="200" width="110" height="40" fill="#0f172a" rx="4" />
          <text x="5" y="215" class="data-label">
            Temp: <tspan id="val-ferm-b" class="data-value"><%= Map.get(@svg_values, "val-ferm-b", "-") %></tspan>°C | Bx: 10
          </text>
          <text x="5" y="230" class="data-label">
            Fase:
            <tspan class="data-value">MAT</tspan>
            (Jacket ON)
          </text>
        </g>

        <%!-- 09. CIP --%>
        <g
          transform="translate(95, 576)"
          class={group_class(@selected_fbe, 9)}
          phx-click="select_fbe_2d"
          phx-value-id="9"
          role="button"
          tabindex="0"
        >
          <rect x="-10" y="-10" width="280" height="150" rx="8" fill="#1e293b" opacity="0.9" />
          <text x="10" y="10" class="eq-title">09. SISTEMA CIP</text>
          <rect x="20" y="30" width="40" height="80" rx="4" fill="url(#metal)" />
          <rect x="22" y="60" width="36" height="48" fill="#3b82f6" opacity="0.6" class="liquid-anim" />
          <rect x="80" y="30" width="40" height="80" rx="4" fill="url(#metal)" />
          <rect x="82" y="50" width="36" height="58" fill="#ef4444" opacity="0.6" class="liquid-anim" />
          <rect x="140" y="30" width="40" height="80" rx="4" fill="url(#metal)" />
          <rect
            x="142"
            y="40"
            width="36"
            height="68"
            fill="#a855f7"
            opacity="0.6"
            class="liquid-anim"
          />
          <circle cx="230" cy="100" r="15" fill="#334155" />
          <circle
            cx="230"
            cy="100"
            r="10"
            fill="#22c55e"
            class="spin-fast"
            stroke-dasharray="2,4"
            stroke="#fff"
          />
          <path
            d="M 230 85 L 230 50 L 280 50"
            stroke="#22c55e"
            stroke-width="3"
            fill="none"
            class="path-cip"
          />
          <rect x="0" y="140" width="280" height="30" fill="#0f172a" rx="4" />
          <text x="5" y="152" class="data-label">
            Bomba CIP:
            <tspan class="data-value">ON</tspan>
            | Vel. Fluxo: 5
          </text>
          <text x="5" y="165" class="data-label">
            Soda Lvl: 75% | Ácido: 96% | Cond:
            <tspan id="val-cond">{Map.get(@svg_values, "val-cond", "-")}</tspan>
          </text>
        </g>

        <%!-- 08. LINHA DE ENVASE --%>
        <g
          transform="translate(438, 535)"
          class={group_class(@selected_fbe, 8)}
          phx-click="select_fbe_2d"
          phx-value-id="8"
          role="button"
          tabindex="0"
        >
          <rect
            x="-10"
            y="-10"
            width="350"
            height="190"
            rx="8"
            fill="#1e293b"
            opacity="0.9"
            stroke="#10b981"
            stroke-width="2"
          />
          <circle cx="330" cy="5" r="3" fill="#22c55e" class="live-led" />
          <text x="10" y="10" class="eq-title">08. LINHA DE ENVASE</text>
          <rect x="20" y="100" width="300" height="10" fill="#334155" />
          <g transform="translate(0, 105)">
            <circle
              cx="40"
              cy="0"
              r="4"
              fill="#0f172a"
              class="spin-fast"
              stroke-dasharray="1,1"
              stroke="#fff"
            /><circle
              cx="80"
              cy="0"
              r="4"
              fill="#0f172a"
              class="spin-fast"
              stroke-dasharray="1,1"
              stroke="#fff"
            />
            <circle
              cx="120"
              cy="0"
              r="4"
              fill="#0f172a"
              class="spin-fast"
              stroke-dasharray="1,1"
              stroke="#fff"
            /><circle
              cx="160"
              cy="0"
              r="4"
              fill="#0f172a"
              class="spin-fast"
              stroke-dasharray="1,1"
              stroke="#fff"
            />
            <circle
              cx="200"
              cy="0"
              r="4"
              fill="#0f172a"
              class="spin-fast"
              stroke-dasharray="1,1"
              stroke="#fff"
            /><circle
              cx="240"
              cy="0"
              r="4"
              fill="#0f172a"
              class="spin-fast"
              stroke-dasharray="1,1"
              stroke="#fff"
            />
            <circle
              cx="280"
              cy="0"
              r="4"
              fill="#0f172a"
              class="spin-fast"
              stroke-dasharray="1,1"
              stroke="#fff"
            />
          </g>
          <rect x="50" y="30" width="40" height="20" rx="2" fill="#475569" />
          <rect x="65" y="50" width="10" height="20" fill="#94a3b8" class="filler-run" />
          <rect x="150" y="20" width="40" height="30" fill="#475569" />
          <rect
            x="165"
            y="50"
            width="10"
            height="15"
            fill="#22c55e"
            class="filler-run"
            style="animation-delay: 0.7s;"
          />
          <defs>
            <clipPath id="belt-clip">
              <rect x="20" y="60" width="300" height="40" />
            </clipPath>
          </defs>
          <g clip-path="url(#belt-clip)">
            <g class="conveyor-run">
              <use href="#bottle" x="20" y="70" />
              <use href="#bottle" x="60" y="70" />
              <use href="#bottle" x="100" y="70" />
              <use href="#bottle" x="140" y="70" />
              <use href="#bottle" x="180" y="70" />
              <use href="#bottle" x="220" y="70" />
              <use href="#bottle" x="260" y="70" />
              <use href="#bottle" x="300" y="70" />
              <use href="#bottle" x="340" y="70" />
            </g>
          </g>
          <rect x="0" y="180" width="350" height="30" fill="#0f172a" rx="4" />
          <text x="5" y="192" class="data-label">
            Velocidade:
            <tspan id="val-bpm" class="data-value">{Map.get(@svg_values, "val-bpm", "-")}</tspan>
            b/m | Fill Head:
            <tspan class="data-value">FILLING</tspan>
          </text>
          <text x="5" y="205" class="data-label">Capper Jam: FALSE | IR Detect: TRUE</text>
        </g>

        <%!-- 10. FROTA AMR --%>
        <g
          transform="translate(868, 576)"
          class={group_class(@selected_fbe, 10)}
          phx-click="select_fbe_2d"
          phx-value-id="10"
          role="button"
          tabindex="0"
        >
          <rect x="-10" y="-10" width="280" height="150" rx="8" fill="#1e293b" opacity="0.9" />
          <circle cx="260" cy="5" r="3" fill="#22c55e" class="live-led" />
          <text x="10" y="10" class="eq-title">10. FROTA AMR (LOGÍSTICA)</text>
          <path d="M 20 60 L 250 60" stroke="#334155" stroke-width="20" stroke-linecap="round" />
          <path d="M 20 60 L 250 60" stroke="#cbd5e1" stroke-width="2" stroke-dasharray="10,10" />
          <g class="amr-run">
            <path d="M 20 15 L -20 -10 L 60 -10 Z" fill="#22c55e" opacity="0.3" />
            <rect x="0" y="5" width="40" height="20" rx="4" fill="#3b82f6" />
            <rect x="5" y="25" width="30" height="5" fill="#0f172a" />
            <circle cx="10" cy="27" r="3" fill="#94a3b8" class="spin-fast" />
            <circle cx="30" cy="27" r="3" fill="#94a3b8" class="spin-fast" />
            <circle cx="20" cy="5" r="4" fill="#22c55e" />
            <rect x="5" y="-15" width="30" height="20" fill="#d97706" />
            <text x="15" y="0" font-size="8" fill="#fff">15kg</text>
          </g>
          <rect x="230" y="40" width="30" height="40" fill="#475569" />
          <path d="M 240 50 L 250 60 L 245 60 L 255 70" stroke="#eab308" stroke-width="2" fill="none" />
          <rect x="0" y="140" width="280" height="30" fill="#0f172a" rx="4" />
          <text x="5" y="152" class="data-label">
            Status AMR 1:
            <tspan class="data-value">PATRULHA</tspan>
          </text>
          <text x="5" y="165" class="data-label">
            Bateria: <tspan id="val-bat" class="data-value"><%= Map.get(@svg_values, "val-bat", "-") %></tspan>% | Payload: 15kg | Loc: Dinâmico
          </text>
        </g>
      </svg>
    </div>
    """
  end

  defp group_class(selected, fbe_id) do
    base = "interactive-group"
    if selected == fbe_id, do: "#{base} svg-2d-group-selected", else: base
  end
end
