import torch
import coremltools as ct
from transformers import AutoTokenizer, AutoModelForTokenClassification
import numpy as np
import sys
import os

# Fix compatibility issue with PyTorch and coremltools
os.environ['PYTORCH_ENABLE_MPS_FALLBACK'] = '1'

class ModelWrapper(torch.nn.Module):
    """Wrapper to ensure model output is compatible with CoreML conversion."""
    def __init__(self, model):
        super().__init__()
        self.model = model
    
    def forward(self, input_ids, attention_mask):
        outputs = self.model(input_ids=input_ids, attention_mask=attention_mask)
        return outputs.logits

def convert_to_coreml(model_path="./models", output_path="./MusicNER.mlpackage"):
    """Convert the fine-tuned PyTorch model to CoreML format for iOS."""
    
    # Normalize path
    import os
    model_path = os.path.abspath(model_path)
    
    # Check if model exists
    if not os.path.exists(model_path):
        raise FileNotFoundError(f"Model directory not found: {model_path}")
    
    print(f"Loading model from: {model_path}")
    tokenizer = AutoTokenizer.from_pretrained(model_path, local_files_only=True, fix_mistral_regex=True)
    model = AutoModelForTokenClassification.from_pretrained(model_path, local_files_only=True)
    model = model.float()  # Ensure model is in float32
    model.eval()
    
    # Wrap the model
    wrapped_model = ModelWrapper(model)
    wrapped_model = wrapped_model.float()  # Ensure wrapper is also float32
    wrapped_model.eval()
    
    print("Model configuration:")
    print(f"  Labels: {model.config.id2label}")
    print(f"  Max length: {tokenizer.model_max_length}")
    
    # Create example input with reasonable max length
    max_seq_length = 128  # Reduced for better iOS performance
    example_text = ["play", "some", "music", "by", "taylor", "swift"]
    example_inputs = tokenizer(
        example_text,
        is_split_into_words=True,
        return_tensors="pt",
        padding="max_length",
        max_length=max_seq_length,
        truncation=True
    )
    
    # Convert inputs to float32 where needed
    attention_mask = example_inputs['attention_mask'].float()
    
    print(f"\nExample input shape: {example_inputs['input_ids'].shape}")
    
    # Trace the model with script mode for better compatibility
    print("\nTracing model...")
    with torch.no_grad():
        try:
            traced_model = torch.jit.trace(
                wrapped_model,
                (example_inputs['input_ids'], attention_mask),
                strict=False
            )
        except:
            print("Script mode failed, trying trace mode...")
            traced_model = torch.jit.script(wrapped_model)
    
    print("Model traced successfully!")
    
    # Convert to CoreML
    print("\nConverting to CoreML...")
    
    # Define inputs with float32 for attention_mask to avoid dtype issues
    input_ids = ct.TensorType(
        name="input_ids",
        shape=(1, max_seq_length),
        dtype=np.float32
    )
    
    attention_mask_input = ct.TensorType(
        name="attention_mask", 
        shape=(1, max_seq_length),
        dtype=np.float32  # Changed to float32 to fix sqrt dtype issues
    )
    
    # Convert with error handling
    coreml_model = ct.convert(
        traced_model,
        inputs=[input_ids, attention_mask_input],
        outputs=[ct.TensorType(name="logits")],
        convert_to="mlprogram",
        minimum_deployment_target=ct.target.iOS15,
        compute_units=ct.ComputeUnit.ALL,
    )
    
    # Add metadata
    coreml_model.author = "Fine-tuned Music NER Model"
    coreml_model.license = "MIT"
    coreml_model.short_description = "Named Entity Recognition model for extracting artists and song titles from music queries"
    coreml_model.version = "1.0"
    
    # Add input descriptions
    coreml_model.input_description["input_ids"] = "Tokenized input sequence (max length: {})".format(max_seq_length)
    coreml_model.input_description["attention_mask"] = "Attention mask for the input sequence"
    
    # Add output description
    coreml_model.output_description["logits"] = "Predicted label logits for each token (shape: [1, seq_length, num_labels])"
    
    # Save the model
    print(f"\nSaving CoreML model to {output_path}...")
    coreml_model.save(output_path)
    
    print("✅ Conversion complete!")
    print(f"\nModel saved to: {output_path}")
    print(f"Max sequence length: {max_seq_length}")
    print(f"Number of labels: {len(model.config.id2label)}")
    print(f"Label mapping: {model.config.id2label}")
    
    # Save label mapping and tokenizer config for iOS app
    print("\nSaving configuration files for iOS...")
    import json
    
    config = {
        "labels": model.config.id2label,
        "max_length": max_seq_length,
        "vocab_size": tokenizer.vocab_size,
        "model_type": model.config.model_type,
        "pad_token_id": tokenizer.pad_token_id,
        "cls_token_id": tokenizer.cls_token_id,
        "sep_token_id": tokenizer.sep_token_id,
        "unk_token_id": tokenizer.unk_token_id,
    }
    
    config_path = output_path.replace(".mlpackage", "_config.json")
    with open(config_path, 'w') as f:
        json.dump(config, f, indent=2)
    
    print(f"Configuration saved to: {config_path}")
    
    # Save tokenizer vocabulary for iOS
    vocab_path = output_path.replace(".mlpackage", "_vocab.json")
    tokenizer.save_vocabulary("./ios_tokenizer")
    print(f"Tokenizer vocabulary saved to: ./ios_tokenizer/")
    
    print("\n" + "="*70)
    print("NEXT STEPS FOR iOS:")
    print("="*70)
    print("1. Add the .mlpackage file to your Xcode project")
    print("2. Import the tokenizer vocabulary files")
    print("3. Use the config.json for label mapping")
    print("4. Tokenize text in Swift before passing to CoreML model")
    print("5. Post-process the logits to extract entities")
    print("\nExample Swift usage:")
    print("""
    // 1. Load the model
    let model = try MusicNER(configuration: MLModelConfiguration())
    
    // 2. Tokenize input (you'll need to implement tokenization)
    let inputIds = tokenizeText(query) // Convert text to token IDs
    let attentionMask = createAttentionMask(inputIds) // Create mask
    
    // 3. Create model input
    let input = MusicNERInput(input_ids: inputIds, attention_mask: attentionMask)
    
    // 4. Run prediction
    let output = try model.prediction(input: input)
    
    // 5. Post-process logits to extract entities
    let entities = extractEntities(logits: output.logits, tokens: tokens)
    """)

def main():
    import sys
    
    model_path = "./models"
    output_path = "./MusicNER.mlpackage"
    
    if len(sys.argv) > 1:
        model_path = sys.argv[1]
    if len(sys.argv) > 2:
        output_path = sys.argv[2]
    
    print("="*70)
    print("PyTorch to CoreML Converter for Music NER Model")
    print("="*70)
    print(f"\nInput model: {model_path}")
    print(f"Output model: {output_path}\n")
    
    # Check dependencies
    try:
        import coremltools
        print(f"coremltools version: {coremltools.__version__}")
    except ImportError:
        print("\n❌ coremltools not found!")
        print("\nInstall with:")
        print("  pip install coremltools")
        sys.exit(1)
    
    try:
        convert_to_coreml(model_path, output_path)
    except Exception as e:
        print(f"\n❌ Error during conversion: {e}")
        import traceback
        traceback.print_exc()
        print("\n" + "="*70)
        print("TROUBLESHOOTING:")
        print("="*70)
        print("1. Try updating coremltools: pip install --upgrade coremltools")
        print("2. Try updating PyTorch: pip install --upgrade torch")
        print("3. Check compatibility: https://github.com/apple/coremltools")
        sys.exit(1)

if __name__ == "__main__":
    main()
