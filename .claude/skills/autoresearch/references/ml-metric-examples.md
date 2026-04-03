# ML Metric Examples for Autoresearch

Metric extraction patterns for machine learning workflows. Referenced from core-principles.md Principle 3.

## Complete ML Configuration

```
/autoresearch
Goal: Improve model accuracy from 85% to 95%
Scope: model.py, config.yaml, data/preprocessing.py
Metric: validation accuracy (higher is better)
Verify: python train.py --eval-only 2>&1 | grep 'val_accuracy' | awk '{print $2}'
Guard: python -c "import torch; m=torch.load('model.pt'); assert m is not None"
Iterations: 20
```

## Python Metric Extraction Patterns

```bash
# Classification accuracy
python train.py --eval 2>&1 | grep 'accuracy' | awk '{print $NF}'

# Validation loss (lower is better)
python train.py 2>&1 | grep 'val_loss' | tail -1 | awk '{print $NF}'

# F1 score
python evaluate.py --metric f1 2>&1 | grep 'f1_score' | awk '{print $2}'

# BLEU score (NLP)
python evaluate.py 2>&1 | grep 'BLEU' | grep -oP '[\d.]+'

# Custom metric extraction script
python -c "
import json
with open('eval_results.json') as f:
    results = json.load(f)
print(results['accuracy'])
"
```

## Error Handling for ML Verification

```bash
# Wrap verify command with timeout and error handling
timeout 300 python train.py --eval-only 2>&1 | grep 'val_accuracy' | awk '{print $2}' || echo "0.0"
# → Returns 0.0 on timeout/crash instead of hanging the loop

# Verify the metric is a valid number
METRIC=$(python train.py --eval 2>&1 | grep 'accuracy' | awk '{print $NF}')
echo "$METRIC" | grep -qP '^\d+\.?\d*$' || { echo "WARN: metric '$METRIC' is not a number"; METRIC="0.0"; }
```

## Reusable Verification Script

```python
# verify_metric.py — reusable verification script for autoresearch
import subprocess, sys, json

def extract_metric(command: str, pattern: str) -> float:
    """Run command, extract metric using pattern, return float."""
    try:
        result = subprocess.run(command, shell=True, capture_output=True, text=True, timeout=300)
        for line in result.stdout.split('\n'):
            if pattern in line:
                # Extract the last number on the line
                numbers = [float(x) for x in line.split() if x.replace('.','',1).isdigit()]
                if numbers:
                    return numbers[-1]
        return 0.0  # Pattern not found
    except subprocess.TimeoutExpired:
        return 0.0  # Timeout — treat as crash
    except Exception as e:
        print(f"WARN: metric extraction failed: {e}", file=sys.stderr)
        return 0.0

if __name__ == "__main__":
    # Usage: python verify_metric.py "python train.py --eval" "accuracy"
    metric = extract_metric(sys.argv[1], sys.argv[2])
    print(metric)
```

```
# Use in autoresearch:
/autoresearch
Verify: python verify_metric.py "python train.py --eval" "accuracy"
```
