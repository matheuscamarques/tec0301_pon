#!/usr/bin/env python3
"""
Ambiente Gymnasium minimalista inspirado no FBE_11 (Smart Grid) e regras R_03/R_08/R_12.
Uso didático para experimentos DRL (PPO/SAC) — não controla o PON real.

Estado (obs): [grid_power_cost_norm, v2g_battery_pct, main_load_kw, ferment_temp_proxy]
Ação discreta: 0=nenhuma, 1=reduzir draw simulado, 2=descarregar V2G

Usage (smoke):
  python -c "from gym_smart_grid_env import SmartGridMicroEnv; e=SmartGridMicroEnv(); print(e.reset())"
"""
from __future__ import annotations

import numpy as np
import gymnasium as gym
from gymnasium import spaces


class SmartGridMicroEnv(gym.Env):
    metadata = {"render_modes": []}

    def __init__(self):
        super().__init__()
        self.observation_space = spaces.Box(
            low=np.array([0.0, 0.0, 0.0, 10.0], dtype=np.float32),
            high=np.array([250.0, 100.0, 600.0, 22.0], dtype=np.float32),
        )
        self.action_space = spaces.Discrete(3)
        self.state = None

    def reset(self, *, seed=None, options=None):
        super().reset(seed=seed)
        self.state = np.array(
            [120.0, 70.0, 200.0, 18.5], dtype=np.float32
        )  # cost, v2g%, load, ferment proxy
        return self.state.copy(), {}

    def step(self, action: int):
        cost, v2g, load, ft = self.state
        reward = 0.0
        if action == 1:
            load = max(50.0, load - 40.0)
            reward += 2.0
        elif action == 2 and v2g > 15:
            v2g -= 8.0
            load = min(550.0, load + 15.0)
            reward += 1.0
        # Penaliza tarifa alta
        reward -= 0.05 * max(0.0, cost - 150.0)
        # Ruído de custo (mercado)
        cost = float(np.clip(cost + self.np_random.normal(0, 5), 80, 250))
        self.state = np.array([cost, v2g, load, ft], dtype=np.float32)
        terminated = bool(cost > 240 and v2g < 10)
        truncated = False
        return self.state.copy(), reward, terminated, truncated, {}


if __name__ == "__main__":
    env = SmartGridMicroEnv()
    obs, _ = env.reset()
    total = 0.0
    for _ in range(50):
        obs, r, term, trunc, _ = env.step(env.action_space.sample())
        total += r
        if term or trunc:
            obs, _ = env.reset()
    print("Smoke OK cumulative_reward~", total)
