#!/usr/bin/env python3
"""
Baseline PPO (Stable-Baselines3) no ambiente didático SmartGridMicroEnv (artigo 15 / Fase 4).
Não controla o PON — apenas smoke de treino.

Usage: python drl_ppo_baseline.py
"""
from __future__ import annotations

try:
    from stable_baselines3 import PPO
except ImportError:
    print("Instale: pip install stable-baselines3")
    raise SystemExit(1)

from gym_smart_grid_env import SmartGridMicroEnv


def main() -> None:
    env = SmartGridMicroEnv()
    model = PPO("MlpPolicy", env, verbose=0, n_steps=32, batch_size=16)
    model.learn(total_timesteps=400)
    obs, _ = env.reset()
    a, _ = model.predict(obs, deterministic=True)
    obs2, r, term, trunc, _ = env.step(int(a))
    print(f"PPO smoke OK step_reward={r:.3f} terminated={term}")


if __name__ == "__main__":
    main()
