"""SageMaker Processing script - preprocesses CSV data."""
import os
import pandas as pd
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import StandardScaler

input_dir = "/opt/ml/processing/input"
output_dir = "/opt/ml/processing/output"

# Read all CSVs from input
dfs = []
for f in os.listdir(input_dir):
    if f.endswith(".csv"):
        dfs.append(pd.read_csv(os.path.join(input_dir, f)))
df = pd.concat(dfs, ignore_index=True)

print(f"Loaded {len(df)} rows, {len(df.columns)} columns")
print(f"Columns: {list(df.columns)}")

# Split features and target (last column is target)
X = df.iloc[:, :-1]
y = df.iloc[:, -1]

# Scale features
scaler = StandardScaler()
X_scaled = pd.DataFrame(scaler.fit_transform(X), columns=X.columns)

# Train/test split
X_train, X_test, y_train, y_test = train_test_split(
    X_scaled, y, test_size=0.2, random_state=42
)

# Save outputs
os.makedirs(os.path.join(output_dir, "train"), exist_ok=True)
os.makedirs(os.path.join(output_dir, "test"), exist_ok=True)

train_df = pd.concat([X_train.reset_index(drop=True), y_train.reset_index(drop=True)], axis=1)
test_df = pd.concat([X_test.reset_index(drop=True), y_test.reset_index(drop=True)], axis=1)

train_df.to_csv(os.path.join(output_dir, "train", "train.csv"), index=False)
test_df.to_csv(os.path.join(output_dir, "test", "test.csv"), index=False)

print(f"Train: {len(train_df)} rows, Test: {len(test_df)} rows")
print("Preprocessing complete")
