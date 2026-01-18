import torch
import coremltools as ct
from transformers import AutoTokenizer, AutoModelForTokenClassification
import numpy as np

def compare_models(model_dir="model", mlpackage_path="MusicNER.mlpackage"):
    """
    Compares the output logits of the original PyTorch model and its CoreML conversion.
    """
    
    # --- 1. Load Tokenizer ---
    try:
        tokenizer = AutoTokenizer.from_pretrained(model_dir)
        print("✅ Tokenizer loaded successfully.")
    except Exception as e:
        print(f"❌ Failed to load tokenizer from '{model_dir}': {e}")
        return

    # --- 2. Load PyTorch Model ---
    try:
        pt_model = AutoModelForTokenClassification.from_pretrained(model_dir)
        pt_model.eval()
        print("✅ PyTorch model loaded successfully.")
    except Exception as e:
        print(f"❌ Failed to load PyTorch model from '{model_dir}': {e}")
        return

    # --- 3. Load CoreML Model ---
    try:
        ml_model = ct.models.MLModel(mlpackage_path)
        print(f"✅ CoreML model loaded successfully from '{mlpackage_path}'.")
    except Exception as e:
        print(f"❌ Failed to load CoreML model from '{mlpackage_path}': {e}")
        return

    # --- 4. Prepare Input ---
    input_text = "play a song by taylor swift"
    print(f"\nComparing outputs for input: '{input_text}'")

    # Split the text into words, which is the expected format for the model.
    words = input_text.split()

    # Tokenize for PyTorch
    pt_inputs = tokenizer(
        words,
        is_split_into_words=True,
        return_tensors="pt",
        truncation=True
    )
    print(pt_inputs)
    
    # Tokenize for CoreML (NumPy)
    np_inputs = tokenizer(
        words,
        is_split_into_words=True,
        return_tensors="np",
        padding="max_length",
        max_length=128,
        truncation=True
    )
    print(np_inputs)
    
    # Prepare CoreML input dictionary
    coreml_input_dict = {
        'input_ids': np_inputs['input_ids'].astype(np.int32),
        'attention_mask': np_inputs['attention_mask'].astype(np.float32)
    }

    # --- 5. Run Inference ---
    # PyTorch inference
    with torch.no_grad():
        pt_outputs = pt_model(**pt_inputs)
        pt_logits = pt_outputs.logits.numpy()

    # CoreML inference
    try:
        coreml_predictions = ml_model.predict(coreml_input_dict)
        coreml_logits = coreml_predictions['logits']
    except Exception as e:
        print(f"❌ CoreML prediction failed: {e}")
        return
        
    # --- 6. Compare Logits ---
    print(f"\nShape of PyTorch logits: {pt_logits.shape}")
    # print(f"Shape of CoreML logits: {coreml_logits.shape}")

    # Calculate the difference
    # abs_diff = np.abs(pt_logits - coreml_logits)
    
    print("--- Logits Comparison ---")
    # print(f"Max absolute difference: {np.max(abs_diff)}")
    # print(f"Mean absolute difference: {np.mean(abs_diff)}")
    # print(f"Sum of absolute difference: {np.sum(abs_diff)}")
    
    # --- 7. Compare Predicted Labels ---
    label_list = ["O", "B-Artist", "I-Artist", "B-WoA", "I-WoA"]
    id2label = {i: label for i, label in enumerate(label_list)}

    pt_predicted_indices = np.argmax(pt_logits, axis=2)[0]
    # coreml_predicted_indices = np.argmax(coreml_logits, axis=2)[0]

    tokens = tokenizer.tokenize(input_text)
    
    print("\n--- Predicted Labels Comparison ---")
    print(f"{ 'Token':<20} { 'PyTorch':<20} { 'CoreML':<20}")
    print("-" * 60)

    for i, token in enumerate(tokens):
        if i < len(pt_predicted_indices):
            pt_label = id2label.get(pt_predicted_indices[i], 'N/A')
            # coreml_label = id2label.get(coreml_predicted_indices[i], 'N/A')
            print(f"{token:<20} {pt_label:<20}")
    
    print("\nIf the differences are large, there is a problem in the conversion process.")
    print("If the labels are different, it confirms the accuracy drop.")

if __name__ == "__main__":
    compare_models()
