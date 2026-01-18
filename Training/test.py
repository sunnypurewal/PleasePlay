import torch
# Defer coremltools import
# import coremltools as ct 
import numpy as np
from transformers import AutoTokenizer, AutoModelForTokenClassification
import os

# --- Global flag for CoreML availability ---
coreml_ok = False
ct = None
try:
    import coremltools as ct
    coreml_ok = True
except ImportError:
    print("⚠️ Could not import coremltools. Skipping CoreML inference.", flush=True)


def load_pt_model(model_path=None): # model_path is no longer used but kept for compatibility
    """Load the BASE PyTorch model and tokenizer for diagnostics."""
    print("--- RUNNING IN DIAGNOSTIC MODE: Using base 'google/mobilebert-uncased' model ---", flush=True)
    model_name = "google/mobilebert-uncased"
    
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModelForTokenClassification.from_pretrained(model_name, num_labels=5, ignore_mismatched_sizes=True)
    
    # Use MPS if available
    if torch.backends.mps.is_available():
        device = torch.device("mps")
        print("Using Apple Silicon GPU (MPS) for PyTorch", flush=True)
    elif torch.cuda.is_available():
        device = torch.device("cuda")
        print("Using CUDA GPU for PyTorch", flush=True)
    else:
        device = torch.device("cpu")
        print("Using CPU for PyTorch", flush=True)
    
    model.to(device)
    model.eval()
    
    return tokenizer, model, device

def parse_text_pt(text, tokenizer, model, device):
    """Parse text and extract entities using the PyTorch model."""
    words = text.split()
    inputs = tokenizer(words, is_split_into_words=True, return_tensors="pt", padding="max_length", max_length=128, truncation=True)
    
    word_ids = inputs.word_ids()
    
    inputs = {k: v.to(device) for k, v in inputs.items()}
    
    with torch.no_grad():
        outputs = model(**inputs)
        predictions = torch.argmax(outputs.logits, dim=2)
    
    predicted_labels = [model.config.id2label[pred.item()] for pred in predictions[0]]
    
    aligned_predictions = []
    previous_word_idx = None
    
    for idx, word_idx in enumerate(word_ids):
        if word_idx is None:
            continue
        if word_idx != previous_word_idx:
            aligned_predictions.append((words[word_idx], predicted_labels[idx]))
        previous_word_idx = word_idx
    
    return aligned_predictions

def parse_text_coreml(text, tokenizer, ml_model, id2label):
    """Parse text and extract entities using the CoreML model."""
    words = text.split()
    
    inputs = tokenizer(words, is_split_into_words=True, return_tensors="np", padding="max_length", max_length=128, truncation=True)
    word_ids = inputs.word_ids()

    coreml_input_dict = {
        'input_ids': inputs['input_ids'].astype(np.int32),
        'attention_mask': inputs['attention_mask'].astype(np.float32)
    }

    coreml_predictions = ml_model.predict(coreml_input_dict)
    coreml_logits = coreml_predictions['logits']
    
    predicted_indices = np.argmax(coreml_logits, axis=2)[0]
    predicted_labels = [id2label.get(idx, 'N/A') for idx in predicted_indices]

    aligned_predictions = []
    previous_word_idx = None
    
    for idx, word_idx in enumerate(word_ids):
        if word_idx is None:
            continue
        if word_idx != previous_word_idx:
            aligned_predictions.append((words[word_idx], predicted_labels[idx]))
        previous_word_idx = word_idx
        
    return aligned_predictions

def main():
    # Load PyTorch model
    tokenizer, pt_model, device = load_pt_model()
    
    # Load CoreML model only if the import was successful
    ml_model = None
    if coreml_ok:
        mlpackage_path = "MusicNER.mlpackage"
        if os.path.exists(mlpackage_path):
            try:
                print(f"Loading CoreML model from '{mlpackage_path}'...", flush=True)
                ml_model = ct.models.MLModel(mlpackage_path)
                print(f"✅ CoreML model loaded successfully.", flush=True)
            except Exception as e:
                print(f"❌ Failed to load CoreML model: {e}", flush=True)
                ml_model = None # Ensure model is None on failure
        else:
            print(f"⚠️ CoreML model not found at '{mlpackage_path}'. Skipping CoreML inference.", flush=True)

    # Example queries
    test_queries = [
        "play a song by taylor swift",
        "looking for songs similar to come together by urbandawn",
        "i love radioheads kid a something similar",
        "music similar to blackout by boris",
        "play some taylor swift songs",
        "anything like shake it off by taylor swift"
    ]
    
    print("\n" + "="*70, flush=True)
    print("Comparing PyTorch and CoreML Music NER Models", flush=True)
    print("="*70 + "\n", flush=True)
    
    for query in test_queries:
        print(f"Query: '{query}'", flush=True)
        
        # PyTorch predictions
        pt_predictions = parse_text_pt(query, tokenizer, pt_model, device)
        
        # CoreML predictions
        coreml_predictions = []
        if ml_model:
            coreml_predictions = parse_text_coreml(query, tokenizer, ml_model, pt_model.config.id2label)

        # Display results side-by-side
        print(f"\n{'Token':<25} {'PyTorch':<20} {'CoreML':<20}", flush=True)
        print("-" * 65, flush=True)
        
        num_tokens = len(pt_predictions)
        for i in range(num_tokens):
            token = pt_predictions[i][0]
            pt_label = pt_predictions[i][1]
            
            # Show CoreML results only if available
            coreml_label = "SKIPPED"
            if ml_model and i < len(coreml_predictions):
                coreml_label = coreml_predictions[i][1]
            elif not coreml_ok:
                 coreml_label = "IMPORT FAILED"

            print(f"{token:<25} {pt_label:<20} {coreml_label:<20}", flush=True)
        
        print("\n" + "-"*70 + "\n", flush=True)

if __name__ == "__main__":
    main()