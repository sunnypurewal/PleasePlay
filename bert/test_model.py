import torch
import argparse
from transformers import AutoTokenizer, AutoModelForTokenClassification

# This script should be run from the 'bert' directory.
# It assumes that the 'bert/model' directory contains a fine-tuned token classification model.

MODEL_PATH = "./model"

def test_text(text, tokenizer, model, id2label):
    """
    Takes a string and prints the model's predictions for it.
    """
    inputs = tokenizer(text, return_tensors="pt")

    with torch.no_grad():
        outputs = model(**inputs)
    
    predictions = torch.argmax(outputs.logits, dim=2)
    
    print("\n--- Predictions ---")
    tokens = tokenizer.convert_ids_to_tokens(inputs["input_ids"][0])
    for token, prediction in zip(tokens, predictions[0]):
        label_id = prediction.item()
        label_name = id2label.get(label_id, f"ID:{label_id}") if id2label else f"ID:{label_id}"
        print(f"{token:<15} {label_name}")
    print("-------------------")


def main():
    """
    Loads the model and runs an interactive loop to test it.
    """
    parser = argparse.ArgumentParser(description="Test a token classification model.")
    parser.add_argument("text", type=str, nargs='?', default=None, help="Text to classify. If not provided, runs in interactive mode.")
    parser.add_argument("--model", type=str, default="./model", help="Path to the model directory (default: ./model)")
    args = parser.parse_args()

    model_path = args.model

    try:
        print(f"Loading tokenizer and model from {model_path}...")
        tokenizer = AutoTokenizer.from_pretrained(model_path)
        model = AutoModelForTokenClassification.from_pretrained(model_path)
        print("✅ Model and tokenizer loaded successfully.")
    except Exception as e:
        print(f"❌ Failed to load model or tokenizer: {e}")
        print(f"Please make sure that the '{model_path}' directory contains a valid Hugging Face token classification model.")
        return

    # Check if the model has a label mapping in its config
    id2label = model.config.id2label if hasattr(model.config, 'id2label') else None
    if not id2label:
        print("\n⚠️  Warning: Model config does not have id2label mapping.")
        print("Predicted label IDs will be shown instead of names.")

    if args.text:
        print(f"Testing with provided text: '{args.text}'")
        test_text(args.text, tokenizer, model, id2label)
    else:
        print("\nInteractive model test. Type 'quit' to exit.")
        while True:
            text = input("Enter text: ")
            if text.lower() == 'quit':
                break
            if not text:
                continue
            test_text(text, tokenizer, model, id2label)

if __name__ == "__main__":
    main()
