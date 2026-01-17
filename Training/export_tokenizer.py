import os
import coremltools as ct
from transformers import AutoTokenizer

def export_tokenizer_model():
    """
    Loads a Hugging Face tokenizer, converts it to a CoreML model,
    and saves it as a .mlpackage file.
    """
    
    # 1. Define Model and Output Path
    model_name = "google/mobilebert-uncased"
    output_mlpackage = "tokenizer.mlpackage"
    vocab_file_name = "vocab.txt"
    
    print(f"Loading tokenizer: {model_name}")
    
    # 2. Load Tokenizer from Hugging Face
    try:
        tokenizer = AutoTokenizer.from_pretrained(model_name)
    except Exception as e:
        print(f"Failed to load tokenizer from Hugging Face: {e}")
        return

    # 3. Save Vocabulary File
    # The ct.models.BERTTokenizer requires a local vocab.txt file.
    try:
        tokenizer.save_vocabulary('.')
        print(f"Saved vocabulary file to {vocab_file_name}")
    except Exception as e:
        print(f"Failed to save vocabulary: {e}")
        return

    # 4. Create CoreML Tokenizer Model
    print("Creating CoreML Tokenizer model...")
    try:
        # Check if the vocab file exists
        if not os.path.exists(vocab_file_name):
            print(f"Error: {vocab_file_name} not found!")
            return
        
        # 5. Save the CoreML Model
        if os.path.exists(output_mlpackage):
            import shutil
            shutil.rmtree(output_mlpackage)
            print(f"Removed existing directory: {output_mlpackage}")

        # The BERTTokenizer is already a MLModel spec
        ct.models.MLModel.save(tokenizer.spec, output_mlpackage)
        
        print(f"✅ Successfully created {output_mlpackage}")

    except Exception as e:
        print(f"❌ CoreML conversion failed: {e}")
    finally:
        # 6. Clean up the vocab file
        if os.path.exists(vocab_file_name):
            os.remove(vocab_file_name)
            print(f"Cleaned up {vocab_file_name}")


if __name__ == "__main__":
    export_tokenizer_model()
