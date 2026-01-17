import torch
from transformers import AutoTokenizer, AutoModelForTokenClassification
import numpy as np

def load_model(model_path="./model"):
    """Load the fine-tuned model and tokenizer."""
    print(f"Loading model from {model_path}...")
    tokenizer = AutoTokenizer.from_pretrained(model_path)
    model = AutoModelForTokenClassification.from_pretrained(model_path)
    
    # Use MPS if available
    if torch.backends.mps.is_available():
        device = torch.device("mps")
        print("Using Apple Silicon GPU (MPS)")
    elif torch.cuda.is_available():
        device = torch.device("cuda")
        print("Using CUDA GPU")
    else:
        device = torch.device("cpu")
        print("Using CPU")
    
    model.to(device)
    model.eval()
    
    return tokenizer, model, device

def parse_text(text, tokenizer, model, device):
    """Parse text and extract entities."""
    # Tokenize input
    tokens = text.split()
    inputs = tokenizer(tokens, is_split_into_words=True, return_tensors="pt", truncation=True)
    
    # Get word_ids before moving to device
    word_ids = inputs.word_ids(0)
    
    # Move to device
    inputs = {k: v.to(device) for k, v in inputs.items()}
    
    # Get predictions
    with torch.no_grad():
        outputs = model(**inputs)
        predictions = torch.argmax(outputs.logits, dim=2)
    
    # Map predictions back to labels
    predicted_labels = [model.config.id2label[pred.item()] for pred in predictions[0]]
    
    # Align tokens with predictions
    aligned_predictions = []
    previous_word_idx = None
    
    for idx, word_idx in enumerate(word_ids):
        if word_idx is None:
            continue
        if word_idx != previous_word_idx:
            aligned_predictions.append((tokens[word_idx], predicted_labels[idx]))
        previous_word_idx = word_idx
    
    return aligned_predictions

def extract_entities(predictions):
    """Extract named entities from predictions."""
    entities = {"Artist": [], "Work of Art": []}
    current_entity = []
    current_type = None
    
    for token, label in predictions:
        if label.startswith("B-"):
            # Save previous entity if exists
            if current_entity and current_type:
                entity_text = " ".join(current_entity)
                entities[current_type].append(entity_text)
            
            # Start new entity
            current_entity = [token]
            current_type = "Artist" if "Artist" in label else "Work of Art"
        
        elif label.startswith("I-") and current_entity:
            # Continue current entity
            current_entity.append(token)
        
        else:  # "O" label
            # Save and reset
            if current_entity and current_type:
                entity_text = " ".join(current_entity)
                entities[current_type].append(entity_text)
            current_entity = []
            current_type = None
    
    # Save last entity if exists
    if current_entity and current_type:
        entity_text = " ".join(current_entity)
        entities[current_type].append(entity_text)
    
    return entities

def main():
    # Load model
    tokenizer, model, device = load_model()
    
    # Example queries
    test_queries = [
        "looking for songs similar to come together by urbandawn",
        "i love radioheads kid a something similar",
        "music similar to blackout by boris",
        "play some taylor swift songs",
        "anything like shake it off by taylor swift"
    ]
    
    print("\n" + "="*70)
    print("Testing Music NER Model")
    print("="*70 + "\n")
    
    for query in test_queries:
        print(f"Query: {query}")
        
        # Parse text
        predictions = parse_text(query, tokenizer, model, device)
        
        # Extract entities
        entities = extract_entities(predictions)
        
        # Display results
        print("\nPredictions:")
        for token, label in predictions:
            print(f"  {token:20s} -> {label}")
        
        print("\nExtracted Entities:")
        if entities["Artist"]:
            print(f"  Artists: {', '.join(entities['Artist'])}")
        if entities["Work of Art"]:
            print(f"  Songs/Albums: {', '.join(entities['Work of Art'])}")
        
        if not entities["Artist"] and not entities["Work of Art"]:
            print("  No entities found")
        
        print("\n" + "-"*70 + "\n")
    
    # Interactive mode
    print("\nInteractive Mode (type 'quit' to exit):")
    while True:
        user_input = input("\nEnter a music query: ").strip()
        
        if user_input.lower() in ['quit', 'exit', 'q']:
            print("Goodbye!")
            break
        
        if not user_input:
            continue
        
        predictions = parse_text(user_input, tokenizer, model, device)
        entities = extract_entities(predictions)
        
        print("\nExtracted Entities:")
        if entities["Artist"]:
            print(f"  Artists: {', '.join(entities['Artist'])}")
        if entities["Work of Art"]:
            print(f"  Songs/Albums: {', '.join(entities['Work of Art'])}")
        if not entities["Artist"] and not entities["Work of Art"]:
            print("  No entities found")

if __name__ == "__main__":
    main()
