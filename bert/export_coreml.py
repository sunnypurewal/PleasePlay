import torch
import numpy
from transformers import AutoTokenizer, AutoModelForTokenClassification
import coremltools as ct
from pathlib import Path
import argparse

def main():
    """
    Converts a fine-tuned Hugging Face token classification model to a Core ML package.
    """
    parser = argparse.ArgumentParser(description="Convert a Hugging Face model to Core ML.")
    parser.add_argument("--model", type=str, default="./model", help="Path to the model directory (default: ./model)")
    args = parser.parse_args()

    model_path = Path(args.model)
    output_path = Path("./MusicNER.mlpackage")
    
    if not model_path.exists():
        print(f"❌ Error: Model directory not found at '{model_path}'.")
        print(f"Please make sure you have a fine-tuned model saved in the '{model_path}' directory.")
        return

    print(f"Loading tokenizer and model from '{model_path}'...")
    try:
        tokenizer = AutoTokenizer.from_pretrained(model_path)
        model = AutoModelForTokenClassification.from_pretrained(model_path, torchscript=True)
        model.eval() # Set model to evaluation mode
        print("✅ Tokenizer and model loaded successfully.")
    except Exception as e:
        print(f"❌ Failed to load model: {e}")
        return

    # --- 1. Trace the model with a sample input ---
    print("Tracing the model with a sample input...")
    # The tokenizer returns a dictionary with 'input_ids', 'attention_mask', etc.
    # The model expects these as separate arguments or unpacked from a dictionary.
    # We will trace it with a sample sentence.
    sample_text = "play music by a new artist"
    inputs = tokenizer(sample_text, return_tensors="pt")
    
    # The traced_model will be a ScriptModule that we can convert.
    try:
        traced_model = torch.jit.trace(model, (inputs['input_ids'], inputs['attention_mask']))
        print("✅ Model traced successfully.")
    except Exception as e:
        print(f"❌ Failed to trace model: {e}")
        return

    # --- 2. Convert the traced model to Core ML ---
    print("Converting the traced model to Core ML...")
    
    # Define the input features for the Core ML model.
    # The input name 'input_ids' should match the name used during tracing.
    # Shape is (1, sequence_length), where sequence length is variable.
    # We use a Shape object with a RangeDim to specify a flexible sequence length.
    shape = ct.Shape(shape=(1, ct.RangeDim(lower_bound=1, upper_bound=tokenizer.model_max_length, default=128)))
    input_ids = ct.TensorType(name="input_ids", shape=shape, dtype=numpy.int32)
    attention_mask = ct.TensorType(name="attention_mask", shape=shape, dtype=numpy.int32)

    # Convert the model
    try:
        # The output of a token classification model is typically 'logits'
        mlmodel = ct.convert(
            traced_model,
            inputs=[input_ids, attention_mask],
            # If your model has a different output name, change 'logits' here.
            # You can inspect the model output to find the correct name.
            outputs=[ct.TensorType(name="logits")],
            minimum_deployment_target=ct.target.iOS18, # Use a recent deployment target
            compute_units=ct.ComputeUnit.ALL,
        )
        print("✅ Model converted to Core ML format.")
    except Exception as e:
        print(f"❌ Core ML conversion failed: {e}")
        return

    
    # --- 3. Set model metadata ---
    print("Setting model metadata...")
    mlmodel.short_description = "MusicNER: Recognizes artists and works of art in text."
    mlmodel.author = "Sunny"
    mlmodel.license = "MIT"

    # You can also add detailed input/output descriptions
    mlmodel.input_description["input_ids"] = "Tokenized input text (indices of tokens in the vocabulary)."
    mlmodel.input_description["attention_mask"] = "Mask to avoid performing attention on padding token indices."
    mlmodel.output_description["logits"] = "The raw, unnormalized output for each token in the sequence."

    # --- 4. Save the Core ML package ---
    print(f"Saving Core ML model to '{output_path}'...")
    try:
        mlmodel.save(str(output_path))
        print(f"✅ Core ML model saved successfully to {output_path}")
    except Exception as e:
        print(f"❌ Failed to save Core ML model: {e}")

if __name__ == "__main__":
    main()
