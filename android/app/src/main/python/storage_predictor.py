"""
Storage growth forecasting using scikit-learn LinearRegression.

Runs entirely on-device via Chaquopy (no internet required).
Called from MainActivity.kt via Chaquopy's Python bridge.

Input:  timestamps  - list of day-index floats (0 = first snapshot)
        used_bytes  - list of floats (storage used at each snapshot)
        total_bytes - float, total device storage capacity

Output: dict with forecasting results and evaluation metrics (MAE, RMSE).
"""

import numpy as np
from sklearn_lite import LinearRegression, mean_absolute_error, mean_squared_error
import math


def forecast(timestamps, used_bytes, total_bytes):
    """
    Fit a linear regression model y = slope*x + intercept to historical
    storage data and predict when storage will be full.

    Returns a dict:
        days_until_full  (int)   : estimated days before storage fills; -1 if not growing
        daily_growth_bytes (float): bytes added per day (regression slope)
        mae              (float) : mean absolute error of the fit (bytes)
        rmse             (float) : root mean squared error of the fit (bytes)
        r2               (float) : coefficient of determination
    """
    try:
        if len(timestamps) < 3:
            return _no_data("insufficient_data")

        X = np.array(timestamps, dtype=float).reshape(-1, 1)
        y = np.array(used_bytes, dtype=float)

        model = LinearRegression()
        model.fit(X, y)

        slope = float(model.coef_[0])
        y_pred = model.predict(X)

        mae = float(mean_absolute_error(y, y_pred))
        rmse = float(math.sqrt(mean_squared_error(y, y_pred)))
        r2 = float(model.score(X, y))

        days_until_full = -1
        if slope > 0:
            current = float(y[-1])
            remaining = float(total_bytes) - current
            if remaining <= 0:
                days_until_full = 0
            else:
                days_until_full = int(math.ceil(remaining / slope))

        return {
            "days_until_full": days_until_full,
            "daily_growth_bytes": max(0.0, slope),
            "mae": mae,
            "rmse": rmse,
            "r2": r2,
        }
    except Exception as e:
        return _no_data(str(e))


def _no_data(reason):
    return {
        "days_until_full": -1,
        "daily_growth_bytes": 0.0,
        "mae": 0.0,
        "rmse": 0.0,
        "r2": 0.0,
        "error": reason,
    }
