"""SageMaker Processing - preprocess CSV data for XGBoost training."""
import os
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

input_dir = "/opt/ml/processing/input"
train_dir = "/opt/ml/processing/output/train"
test_dir = "/opt/ml/processing/output/test"

dfs = []
for f in os.listdir(input_dir):
    if f.endswith(".csv"):
        dfs.append(pd.read_csv(os.path.join(input_dir, f)))
df = pd.concat(dfs, ignore_index=True)

print(f"Loaded {len(df)} rows, {len(df.columns)} columns")

# Last column is target — XGBoost expects target as first column
X = df.iloc[:, :-1]
y = df.iloc[:, -1]

scaler = StandardScaler()
X_scaled = pd.DataFrame(scaler.fit_transform(X), columns=X.columns)

X_train, X_test, y_train, y_test = train_test_split(
    X_scaled, y, test_size=0.2, random_state=42
)

os.makedirs(train_dir, exist_ok=True)
os.makedirs(test_dir, exist_ok=True)

# XGBoost expects target as first column, no header
train_df = pd.concat([y_train.reset_index(drop=True), X_train.reset_index(drop=True)], axis=1)
test_df = pd.concat([y_test.reset_index(drop=True), X_test.reset_index(drop=True)], axis=1)

train_df.to_csv(os.path.join(train_dir, "train.csv"), index=False, header=False)
test_df.to_csv(os.path.join(test_dir, "test.csv"), index=False, header=False)

print(f"Train: {len(train_df)} rows, Test: {len(test_df)} rows")
