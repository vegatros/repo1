"""SageMaker Processing - evaluate trained model against test data."""
import json
import os
import tarfile
import pandas as pd
import numpy as np
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score, roc_auc_score
import xgboost as xgb

model_dir = "/opt/ml/processing/model"
test_dir = "/opt/ml/processing/test"
eval_dir = "/opt/ml/processing/evaluation"
os.makedirs(eval_dir, exist_ok=True)

# Extract model artifact
model_tar = None
for root, dirs, files in os.walk(model_dir):
    for f in files:
        if f.endswith(".tar.gz"):
            model_tar = os.path.join(root, f)
            break

with tarfile.open(model_tar, "r:gz") as tar:
    tar.extractall(path="/tmp/model")

model = xgb.Booster()
model.load_model("/tmp/model/xgboost-model")

# Load test data (target is first column)
test_df = pd.read_csv(os.path.join(test_dir, "test.csv"), header=None)
y_true = test_df.iloc[:, 0].values
X_test = test_df.iloc[:, 1:].values

dtest = xgb.DMatrix(X_test)
y_prob = model.predict(dtest)
y_pred = (y_prob >= 0.5).astype(int)

metrics = {
    "metrics": {
        "accuracy": {"value": float(accuracy_score(y_true, y_pred))},
        "precision": {"value": float(precision_score(y_true, y_pred, zero_division=0))},
        "recall": {"value": float(recall_score(y_true, y_pred, zero_division=0))},
        "f1": {"value": float(f1_score(y_true, y_pred, zero_division=0))},
        "auc": {"value": float(roc_auc_score(y_true, y_prob))},
    }
}

print(json.dumps(metrics, indent=2))

with open(os.path.join(eval_dir, "evaluation.json"), "w") as f:
    json.dump(metrics, f, indent=2)

print("Evaluation complete")
