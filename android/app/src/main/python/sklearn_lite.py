"""
sklearn_lite.py
================
Drop-in pure-Python/NumPy replacements for the small subset of
scikit-learn functionality used by engine_forecast.py and engine_scoring.py.

This exists because scikit-learn has no pre-built Android wheel in
Chaquopy's package index (it requires compiled SciPy/Fortran extensions),
so on-device execution needs a pure-Python equivalent.

Drop this file alongside the other engine_*.py files and change:
    from sklearn.linear_model import LinearRegression
    from sklearn.metrics import mean_absolute_error, mean_squared_error
    from sklearn.preprocessing import MinMaxScaler
to:
    from sklearn_lite import LinearRegression, mean_absolute_error, mean_squared_error, MinMaxScaler

No other code changes are required — the class/function signatures
and behaviour match the subset of sklearn actually used.

=== EDITS TO MAKE ===

In engine_forecast.py, change:
    from sklearn.linear_model import LinearRegression
    from sklearn.metrics import mean_absolute_error, mean_squared_error
to:
    from sklearn_lite import LinearRegression, mean_absolute_error, mean_squared_error

In engine_scoring.py, change:
    from sklearn.preprocessing import MinMaxScaler
to:
    from sklearn_lite import MinMaxScaler
"""

import numpy as np


class LinearRegression:
    """
    Minimal drop-in replacement for sklearn.linear_model.LinearRegression.
    Supports single-feature (n_samples, 1) inputs, which is all that
    engine_forecast.py uses (day_index -> used_bytes).

    Uses ordinary least squares via the normal equation.
    """

    def __init__(self):
        self.coef_ = None
        self.intercept_ = None

    def fit(self, X, y):
        X = np.asarray(X, dtype=float)
        y = np.asarray(y, dtype=float)

        if X.ndim == 1:
            X = X.reshape(-1, 1)

        n_samples, n_features = X.shape

        # Add intercept column
        X_design = np.hstack([np.ones((n_samples, 1)), X])

        # Solve via least squares (numerically stable, no sklearn needed)
        coeffs, _, _, _ = np.linalg.lstsq(X_design, y, rcond=None)

        self.intercept_ = float(coeffs[0])
        self.coef_ = coeffs[1:]  # array of length n_features

        return self

    def predict(self, X):
        X = np.asarray(X, dtype=float)
        if X.ndim == 1:
            X = X.reshape(-1, 1)
        return X @ self.coef_ + self.intercept_


def mean_absolute_error(y_true, y_pred):
    y_true = np.asarray(y_true, dtype=float)
    y_pred = np.asarray(y_pred, dtype=float)
    return float(np.mean(np.abs(y_true - y_pred)))


def mean_squared_error(y_true, y_pred):
    y_true = np.asarray(y_true, dtype=float)
    y_pred = np.asarray(y_pred, dtype=float)
    return float(np.mean((y_true - y_pred) ** 2))


class MinMaxScaler:
    """
    Minimal drop-in replacement for sklearn.preprocessing.MinMaxScaler.
    Supports fit_transform on a 2D column array, matching the usage in
    engine_scoring.py: arr.reshape(-1, 1) -> fit_transform(arr).
    Scales to the default [0, 1] range.
    """

    def __init__(self, feature_range=(0, 1)):
        self.feature_range = feature_range
        self.data_min_ = None
        self.data_max_ = None

    def fit(self, X):
        X = np.asarray(X, dtype=float)
        self.data_min_ = X.min(axis=0)
        self.data_max_ = X.max(axis=0)
        return self

    def transform(self, X):
        X = np.asarray(X, dtype=float)
        data_range = self.data_max_ - self.data_min_
        # Avoid division by zero (constant column -> all zeros, matches
        # the caller's existing guard in engine_scoring.py, but safe anyway)
        data_range = np.where(data_range == 0, 1, data_range)

        lo, hi = self.feature_range
        scaled = (X - self.data_min_) / data_range
        return scaled * (hi - lo) + lo

    def fit_transform(self, X):
        self.fit(X)
        return self.transform(X)
