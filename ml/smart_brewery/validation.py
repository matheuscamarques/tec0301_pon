"""
Validação temporal para séries (artigo 16): splits sem vazamento entre treino e teste.

Reutilizado por pilotos OEE, telemetria e anomalias. Preferir *walk-forward* com
janelas temporais ordenadas em vez de amostragem i.i.d.
"""
from __future__ import annotations

from dataclasses import dataclass
from typing import Generator, Literal, Sequence

import numpy as np


def time_ordered_indices(n: int, train_ratio: float = 0.8) -> tuple[np.ndarray, np.ndarray]:
    """Único split temporal: primeiros ``train_ratio * n`` índices = treino, resto = teste."""
    if n < 2:
        raise ValueError("n must be >= 2")
    split = max(1, int(n * train_ratio))
    if split >= n:
        split = n - 1
    idx = np.arange(n)
    return idx[:split], idx[split:]


@dataclass(frozen=True)
class WalkForwardFold:
    train_slice: slice
    test_slice: slice


def walk_forward_folds(
    n_samples: int,
    *,
    min_train_size: int,
    test_size: int,
    step: int = 1,
    mode: Literal["rolling", "anchored"] = "rolling",
) -> list[WalkForwardFold]:
    """
    Gera dobras walk-forward ao longo do eixo temporal (índices 0..n-1).

    - **rolling**: a janela de treino desliza (tamanho ~constante se possível).
    - **anchored**: treino sempre começa em 0; apenas o fim do treino avança.

    Parâmetros típicos: ``test_size=1`` (previsão um passo), ``step=1``.
    """
    if n_samples < min_train_size + test_size:
        return []
    folds: list[WalkForwardFold] = []
    t = min_train_size
    while t + test_size <= n_samples:
        if mode == "anchored":
            train_start = 0
        else:
            train_start = t - min_train_size
        train_end = t
        test_end = t + test_size
        folds.append(
            WalkForwardFold(
                train_slice=slice(train_start, train_end),
                test_slice=slice(train_end, test_end),
            )
        )
        t += step
    return folds


def walk_forward_yield_arrays(
    X: np.ndarray,
    y: np.ndarray,
    *,
    min_train_size: int,
    test_size: int,
    step: int = 1,
    mode: Literal["rolling", "anchored"] = "rolling",
) -> Generator[tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray], None, None]:
    """Yield (X_train, y_train, X_test, y_test) por dobra."""
    n = X.shape[0]
    assert y.shape[0] == n
    for fold in walk_forward_folds(
        n,
        min_train_size=min_train_size,
        test_size=test_size,
        step=step,
        mode=mode,
    ):
        tr = fold.train_slice
        te = fold.test_slice
        yield X[tr], y[tr], X[te], y[te]


def aggregate_walk_forward_metrics(
    y_true_list: Sequence[np.ndarray],
    y_pred_list: Sequence[np.ndarray],
) -> dict[str, float]:
    """Concatena predições de todas as dobras e calcula MAE / RMSE globais."""
    yt = np.concatenate([np.asarray(a).ravel() for a in y_true_list])
    yp = np.concatenate([np.asarray(a).ravel() for a in y_pred_list])
    mae = float(np.mean(np.abs(yt - yp)))
    rmse = float(np.sqrt(np.mean((yt - yp) ** 2)))
    return {"mae": mae, "rmse": rmse, "n_test_points": float(len(yt))}
