import torch
from transformers import AutoTokenizer, AutoModelForTokenClassification

# The model 'distilbert/distilbert-base-cased-distilled-squad' is not pre-trained for token classification.
# When loading it with AutoModelForTokenClassification, a new token classification head is added and randomly initialized.
# This means the predictions will not be meaningful until the model is fine-tuned for a specific token classification task.
model_name = "distilbert/distilbert-base-cased-distilled-squad"

tokenizer = AutoTokenizer.from_pretrained(model_name)

# We need to specify the number of labels for the new token classification head.
# For this example, we'll use 5 labels, but this should be adapted to your specific task.
# A common use case is Named Entity Recognition (NER) with labels like O, B-PER, I-PER, B-ORG, I-ORG.
num_labels = 5
model = AutoModelForTokenClassification.from_pretrained(model_name, num_labels=num_labels)

text = "My name is Sunny and I live in Cupertino"
inputs = tokenizer(text, return_tensors="pt")

with torch.no_grad():
    outputs = model(**inputs)

# The output logits have the shape (batch_size, sequence_length, num_labels).
# We can get the predicted class for each token by taking the argmax over the last dimension.
predictions = torch.argmax(outputs.logits, dim=2)

# Let's print each token and its predicted label ID.
# The label IDs (0 to 4 in this case) don't have names yet.
# For a real task, you would have a mapping from IDs to label names (e.g., {0: "O", 1: "B-PERSON"}).
tokens = tokenizer.convert_ids_to_tokens(inputs["input_ids"][0])
for token, prediction in zip(tokens, predictions[0]):
    print(f"{token:<15} {prediction.item()}")


# import torch
# import coremltools as ct
# from transformers import AutoTokenizer, AutoModelForSequenceClassification
# import os

# def convert_distilbert_to_coreml(model_name="distilbert/distilbert-base-cased-distilled-squad", output_dir="."):
#     """
#     Downloads a DistilBERT model from Hugging Face and converts it to a Core ML mlpackage.

#     Args:
#         model_name (str): The name of the Hugging Face model to download.
#         output_dir (str): The directory to save the converted model.
#     """
#     print(f"Starting conversion for model: {model_name}")

#     # --- 1. Load Hugging Face Model and Tokenizer ---
#     try:
#         print("Loading tokenizer...")
#         tokenizer = AutoTokenizer.from_pretrained(
#             model_name,
#         )
#         print("Loading PyTorch model...")
#         # Using torch.jit.script=True is often more robust for conversion
#         # as it handles control flow better than tracing.
#         model = AutoModelForSequenceClassification.from_pretrained(
#             model_name,
#             dtype=torch.float16,
#             device_map="auto",
#             attn_implementation="sdpa"
#         )
#         model.eval()  # Set model to evaluation mode
#         print("✅ Model and tokenizer loaded successfully.")
#     except Exception as e:
#         print(f"❌ Failed to load model or tokenizer: {e}")
#         return

#     # --- 2. Prepare Example Input ---
#     # Create a sample input to trace the model's execution graph.
#     # The sequence length (128 here) should be representative of your expected inputs.
#     example_text = "Play eminem's first album"
#     print(f"\nUsing example text for tracing: '{example_text}'")

#     # The tokenizer returns a dictionary with 'input_ids' and 'attention_mask'.
#     # We need to trace the model with these inputs.
#     tokenized_input = tokenizer(
#         example_text,
#         return_tensors="pt",
#         padding="max_length",
#         max_length=128,
#         truncation=True
#     )
#     example_input_ids = tokenized_input['input_ids']
#     example_attention_mask = tokenized_input['attention_mask']

#     # --- 3. Trace the Model ---
#     print("Tracing the model with example inputs...")
#     # The model expects a tuple of inputs if there are multiple.
#     traced_model = torch.jit.trace(model, (example_input_ids, example_attention_mask))
#     print("✅ Model traced successfully.")

#     # --- 4. Convert to Core ML ---
#     print("\nConverting model to Core ML format...")
#     # Define the input specifications for the Core ML model.
#     # Using dynamic sequence length with RangeDim for flexibility.
#     sequence_length = ct.RangeDim(1, tokenizer.model_max_length, default=128)

#     inputs = [
#         ct.TensorType(name="input_ids", shape=(1, sequence_length), dtype=int),
#         ct.TensorType(name="attention_mask", shape=(1, sequence_length), dtype=int)
#     ]

#     # Convert the traced model. 'mlprogram' is the modern, recommended format.
#     mlmodel = ct.convert(traced_model, inputs=inputs, convert_to="mlprogram")
#     print("✅ Model converted to Core ML.")

#     # --- 5. Save the Core ML Model ---
#     output_path = os.path.join(output_dir, "DistilBERT.mlpackage")
#     print(f"Saving model to: {output_path}")
#     mlmodel.save(output_path)
#     print(f"🎉 Successfully saved Core ML model at {output_path}")

# if __name__ == "__main__":
#     convert_distilbert_to_coreml()
