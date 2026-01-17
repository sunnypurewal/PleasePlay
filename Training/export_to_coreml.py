import os
import torch
import coremltools as ct
from transformers import AutoTokenizer, AutoModelForTokenClassification
import shutil
import numpy as np

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

def export_model(model_dir):
    """
    Exports a Hugging Face model to CoreML format via PyTorch Tracing.
    Direct PyTorch conversion is used because coremltools dropped direct ONNX support in newer versions.
    """
    
    model_name = os.path.basename(os.path.normpath(model_dir))
    output_mlpackage = f"{model_name}.mlpackage"
    
    print(f"Processing model: {model_dir}")
    print(f"Output: {output_mlpackage}")
    
    # 1. Load Model
    print("Loading PyTorch model...")
    try:
        # Added fix_mistral_regex=True based on user request/warning
        tokenizer = AutoTokenizer.from_pretrained(model_dir, local_files_only=True, fix_mistral_regex=True)
        model = AutoModelForTokenClassification.from_pretrained(model_dir, local_files_only=True)
        
        # CRITICAL FIX: Ensure model is in float32 to verify operations like sqrt don't receive int32
        model = model.float()
        model.eval()
        
        # Wrap the model
        wrapper = ModelWrapper(model)
        wrapper = wrapper.float()
        wrapper.eval()
        
    except Exception as e:
        print(f"Failed to load model from {model_dir}: {e}")
        return

    # 2. Trace Model
    print("Tracing PyTorch model...")
    dummy_input_text = ["play", "a", "song", "by", "taylor", "swift"]
    inputs = tokenizer(
        dummy_input_text, 
        return_tensors="pt", 
        is_split_into_words=True,
        padding="max_length",
        max_length=128,
        truncation=True
    )
    
    input_ids = inputs["input_ids"]
    # CRITICAL FIX: Cast attention mask to float before tracing
    attention_mask = inputs["attention_mask"].float()
    
    try:
        with torch.no_grad():
            traced_model = torch.jit.trace(
                wrapper,
                (input_ids, attention_mask),
                strict=False
            )
    except Exception as e:
        print(f"Tracing failed: {e}")
        return
    
    # 3. Convert to CoreML
    print("Converting to CoreML...")
    try:
        # Define CoreML inputs
        input_ids_type = ct.TensorType(
            name="input_ids",
            shape=(1, 128),
            dtype=np.int32
        )
        
        # Use float32 for attention mask to match the traced graph
        attention_mask_type = ct.TensorType(
            name="attention_mask", 
            shape=(1, 128),
            dtype=np.float32 
        )
        
        mlmodel = ct.convert(
            traced_model,
            inputs=[input_ids_type, attention_mask_type],
            outputs=[ct.TensorType(name="logits")],
            convert_to="mlprogram",
            minimum_deployment_target=ct.target.iOS16,
            compute_units=ct.ComputeUnit.ALL
        )
        
        # Metadata
        mlmodel.author = "Automated Converter"
        mlmodel.short_description = f"CoreML version of {model_name}"
        # Removed incorrect package_path assignment
        
        # Save
        if os.path.exists(output_mlpackage):
            shutil.rmtree(output_mlpackage)
            
        mlmodel.save(output_mlpackage)
        print(f"✅ Successfully created {output_mlpackage}")
        
    except Exception as e:
        print(f"❌ CoreML conversion failed: {e}")

def main():
    target_dir = "model"
    
    if not os.path.exists(target_dir):
        print(f"Directory '{target_dir}' not found.")
        return

    # path is a model itself?
    if os.path.exists(os.path.join(target_dir, "config.json")):
        export_model(target_dir)
    else:
        # Iterate over subdirectories
        print(f"Scanning '{target_dir}' for models...")
        found = False
        for item in os.listdir(target_dir):
            full_path = os.path.join(target_dir, item)
            if os.path.isdir(full_path) and os.path.exists(os.path.join(full_path, "config.json")):
                export_model(full_path)
                found = True
        
        if not found:
            print("No models found. (looked for config.json in subfolders)")

if __name__ == "__main__":
    main()
