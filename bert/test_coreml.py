
import coremltools as ct
import numpy as np
from transformers import AutoTokenizer, AutoConfig
import argparse
from pathlib import Path

def main():
    """
    Loads and runs inference on a Core ML token classification model.
    """
    parser = argparse.ArgumentParser(description="Test a Core ML token classification model.")
    parser.add_argument("text", type=str, nargs='?', default=None, help="Text to classify. If not provided, runs in interactive mode.")
    args = parser.parse_args()

    model_path = Path("./MusicNER.mlpackage")
    tokenizer_path = Path("./model")

    if not model_path.exists():
        print(f"❌ Error: Core ML model not found at '{model_path}'.")
        print("Please run the export_coreml.py script first.")
        return
        
    if not tokenizer_path.exists():
        print(f"❌ Error: Tokenizer/Config not found at '{tokenizer_path}'.")
        print("Please make sure the fine-tuned model and tokenizer are in the './model' directory.")
        return

    print("Loading Core ML model, tokenizer, and config...")
    try:
        # Load the Core ML model
        mlmodel = ct.models.MLModel(str(model_path))
        
        # Load the tokenizer and config
        tokenizer = AutoTokenizer.from_pretrained(tokenizer_path)
        config = AutoConfig.from_pretrained(tokenizer_path)
        print("✅ Model, tokenizer, and config loaded successfully.")
    except Exception as e:
        print(f"❌ Failed to load model, tokenizer, or config: {e}")
        return

    # Get the label mapping from the config and ensure keys are integers
    id2label = {int(k): v for k, v in config.id2label.items()} if hasattr(config, 'id2label') else {
        0: "O", 1: "B-Artist", 2: "I-Artist", 3: "B-WoA", 4: "I-WoA"
    }
    
    def extract_entities(tokens, predictions):
        """
        Combines token predictions into full-word entities.
        """
        entities = []
        current_entity_tokens = []
        current_entity_label = None

        for token, prediction in zip(tokens, predictions):
            label_id = prediction
            label_name = id2label.get(label_id)

            if label_name and label_name.startswith("B-"):
                if current_entity_tokens:
                    entity_string = tokenizer.convert_tokens_to_string(current_entity_tokens)
                    entities.append({"entity": entity_string, "label": current_entity_label})
                
                current_entity_tokens = [token]
                current_entity_label = label_name[2:]

            elif label_name and label_name.startswith("I-"):
                if current_entity_label == label_name[2:]:
                    current_entity_tokens.append(token)
                else: # Malformed I- tag, reset
                    if current_entity_tokens:
                        entity_string = tokenizer.convert_tokens_to_string(current_entity_tokens)
                        entities.append({"entity": entity_string, "label": current_entity_label})
                    current_entity_tokens = []
                    current_entity_label = None
            else: # O-tag or something else
                if current_entity_tokens:
                    entity_string = tokenizer.convert_tokens_to_string(current_entity_tokens)
                    entities.append({"entity": entity_string, "label": current_entity_label})
                current_entity_tokens = []
                current_entity_label = None

        if current_entity_tokens:
            entity_string = tokenizer.convert_tokens_to_string(current_entity_tokens)
            entities.append({"entity": entity_string, "label": current_entity_label})
            
        return entities

    def predict(text):
        """
        Takes a string, runs it through the Core ML model, and prints the predictions.
        """
        print(f"\n--- Predictions for: '{text}' ---")
        
        # 1. Tokenize the input
        inputs = tokenizer(text, return_tensors="pt")
        input_ids = inputs["input_ids"].numpy().astype(np.int32)
        print(input_ids)
        print(input_ids.shape)
        attention_mask = inputs["attention_mask"].numpy().astype(np.int32)
        print(attention_mask)
        print(attention_mask.shape)
        
        coreml_inputs = {"input_ids": input_ids, "attention_mask": attention_mask}
        print(coreml_inputs)

        # 2. Run prediction
        try:
            prediction_output = mlmodel.predict(coreml_inputs)
        except Exception as e:
            print(f"❌ Prediction failed: {e}")
            return
            
        # 3. Post-process the output
        logits = prediction_output['logits']
        predictions = np.argmax(logits, axis=2)[0] # Get the first (and only) batch
        print(predictions)
        
        # 4. Align tokens and labels
        tokens = tokenizer.convert_ids_to_tokens(input_ids[0])
        print(tokens)
        
        print("\n[Token Predictions]")
        for token, prediction in zip(tokens, predictions):
            label_id = prediction
            label_name = id2label.get(label_id, f"ID:{label_id}")
            if label_name is None:
                label_name = f"UNK:{label_id}"
            print(f"{token:<15} {label_name}")
        print("---------------------------------")
        
        # 5. Extract and print entities
        entities = extract_entities(tokens, predictions)
        if entities:
            print("\n[Extracted Entities]")
            for entity in entities:
                print(f"- {entity['entity']} ({entity['label']})")
            print("---------------------------------")
        else:
            print("\nNo entities found.")

    if args.text:
        predict(args.text)
    else:
        print("\nInteractive model test. Type 'quit' to exit.")
        while True:
            user_text = input("Enter text: ")
            if user_text.lower() == 'quit':
                break
            if not user_text:
                continue
            predict(user_text)

if __name__ == "__main__":
    main()

