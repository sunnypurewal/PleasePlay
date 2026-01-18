import coremltools as ct
import numpy as np
import sys
from transformers import AutoTokenizer

def test_model_predictions(mlpackage_path):
    """
    Loads a CoreML model package, tokenizes a sample text, runs a prediction,
    and prints the output.
    """
    
    try:
        print(f"Loading model: {mlpackage_path}")
        model = ct.models.MLModel(mlpackage_path)
        print("Model loaded successfully.")
    except Exception as e:
        print(f"❌ Failed to load model: {e}")
        return

    # --- Model Details ---
    print("\n--- Model Description ---")
    print(f"Inputs: {model.input_description}")
    print(f"Outputs: {model.output_description}")
    print("-------------------------\n")

    # --- Prepare Input ---
    # Manually tokenize the input text before sending it to the model.
    tokenizer = AutoTokenizer.from_pretrained("model")
    input_text = "play a song by taylor swift"
    print(f"Tokenizing input text: '{input_text}'")

    tokenized_input = tokenizer(
        input_text,
        return_tensors="np",  # Return NumPy arrays
        padding="max_length",
        max_length=128,       # Must match the model's expected input size
        truncation=True
    )
    
    # The model expects int32 for input_ids, so we cast it.
    input_ids = tokenized_input['input_ids'].astype(np.int32)
    # The attention mask needs to be float32 for many CoreML models
    attention_mask = tokenized_input['attention_mask'].astype(np.float32)

    print(f"Shape of input_ids: {input_ids.shape}, Type: {input_ids.dtype}")
    print(f"Shape of attention_mask: {attention_mask.shape}, Type: {attention_mask.dtype}")
    print(input_ids)
    print(attention_mask)
    
    # --- Run Prediction ---
    try:
        # The input is a dictionary where keys match the model's input names
        # (e.g., 'input_ids', 'attention_mask')
        input_data = {
            'input_ids': input_ids,
            'attention_mask': attention_mask
        }
        print("\nRunning prediction...")
        predictions = model.predict(input_data)
    except Exception as e:
        print(f"❌ Prediction failed: {e}")
        return

    # --- Process and Print Output ---
    # The output key 'logits' was defined in the export script.
    logits = predictions.get('logits')
    if logits is None:
        print("❌ 'logits' key not found in prediction output.")
        print(f"Available keys: {predictions.keys()}")
        return
        
    print(f"\nLogits output shape: {logits.shape}")

    # --- Interpret the Results ---
    label_list = ["O", "B-Artist", "I-Artist", "B-WoA", "I-WoA"]
    id2label = {i: label for i, label in enumerate(label_list)}
    
    tokens = tokenizer.tokenize(input_text)
    predicted_indices = np.argmax(logits, axis=2)[0]

    print("\n--- Predicted Labels per Token ---")
    for i, token in enumerate(tokens):
        if i < len(predicted_indices):
            pred_idx = predicted_indices[i]
            label = id2label.get(pred_idx, 'UNKNOWN_LABEL')
            print(f"'{token}' -> {label} (id: {pred_idx})")
    print("----------------------------------\n")


if __name__ == "__main__":
    if len(sys.argv) > 1:
        model_path = sys.argv[1]
    else:
        # Defaulting to 'model.mlpackage', but this script is now best for
        # models that do NOT have the tokenizer built in.
        model_path = "model.mlpackage"
    
    if not model_path.endswith('.mlpackage'):
        print(f"Error: Provided path '{model_path}' does not end with .mlpackage")
    else:
        test_model_predictions(model_path)
