

print("Starting script...")
import torch
print("Imported torch.")
from transformers import AutoTokenizer, AutoModelForTokenClassification, TrainingArguments, Trainer, DataCollatorForTokenClassification
print("Imported transformers.")
from datasets import Dataset
print("Imported datasets.")

def load_bio_file(file_path):
    """Load a BIO format file and return tokens and NER tags."""
    tokens = []
    ner_tags = []
    current_tokens = []
    current_tags = []
    
    with open(file_path, 'r', encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:  # Empty line indicates end of sentence
                if current_tokens:
                    tokens.append(current_tokens)
                    ner_tags.append(current_tags)
                    current_tokens = []
                    current_tags = []
            else:
                parts = line.split('\t')
                if len(parts) == 2:
                    token, tag = parts
                    current_tokens.append(token)
                    current_tags.append(tag)
        
        # Add the last sentence if it exists
        if current_tokens:
            tokens.append(current_tokens)
            ner_tags.append(current_tags)
    
    return {"tokens": tokens, "ner_tags": ner_tags}

def main():
    # Detect and configure Apple Silicon MPS device
    if torch.backends.mps.is_available():
        device = torch.device("mps")
        print("Apple Silicon GPU (MPS) detected and will be used for training!")
    elif torch.cuda.is_available():
        device = torch.device("cuda")
        print("CUDA GPU detected and will be used for training!")
    else:
        device = torch.device("cpu")
        print("No GPU detected, using CPU for training.")
    
    # Define label mapping first
    label_list = ["O", "B-Artist", "I-Artist", "B-WoA", "I-WoA"]
    label2id = {label: i for i, label in enumerate(label_list)}
    id2label = {i: label for i, label in enumerate(label_list)}
    
    # Load the tokenizer and model with correct number of labels
    model_name = "distilbert/distilbert-base-cased-distilled-squad"
    print(f"Loading tokenizer and model from {model_name}...")
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModelForTokenClassification.from_pretrained(
        model_name,
        num_labels=len(label_list),
        id2label=id2label,
        label2id=label2id,
        ignore_mismatched_sizes=True
    )
    print("Tokenizer and model loaded.")

    # Load the custom datasets
    print("Loading custom IOB datasets...")
    
    dataset_dirs = [
        "data/reddit+shsyt/dataset1", 
        "data/reddit+shsyt/dataset2", 
        "data/reddit+shsyt/dataset3", 
        "data/reddit+shsyt/dataset4",
        "data/reddit+shsyt/dataset5"
    ]
    
    all_train_tokens = []
    all_train_tags = []
    all_test_tokens = []
    all_test_tags = []

    for dataset_dir in dataset_dirs:
        train_path = f"{dataset_dir}/train.IOB"
        test_path = f"{dataset_dir}/test.IOB"
        
        try:
            train_data_part = load_bio_file(train_path)
            test_data_part = load_bio_file(test_path)
            
            all_train_tokens.extend(train_data_part["tokens"])
            all_train_tags.extend(train_data_part["ner_tags"])
            all_test_tokens.extend(test_data_part["tokens"])
            all_test_tags.extend(test_data_part["ner_tags"])
            print(f"Successfully loaded {dataset_dir}: {len(train_data_part['tokens'])} train, {len(test_data_part['tokens'])} test examples.")
        except FileNotFoundError as e:
            print(f"⚠️  Warning: Could not find {e.filename}. Skipping this file.")

    train_data = {"tokens": all_train_tokens, "ner_tags": all_train_tags}
    test_data = {"tokens": all_test_tokens, "ner_tags": all_test_tags}
    
    if not train_data["tokens"] or not test_data["tokens"]:
        print("❌ Error: No training or testing data was loaded. Please check the dataset paths. Exiting.")
        return

    print(f"\n✅ All datasets loaded: {len(train_data['tokens'])} total train examples, {len(test_data['tokens'])} total test examples")
    
    print(f"Label mapping: {label2id}")
    
    # Convert string labels to integers
    train_data["ner_tags"] = [[label2id[tag] for tag in tags] for tags in train_data["ner_tags"]]
    test_data["ner_tags"] = [[label2id[tag] for tag in tags] for tags in test_data["ner_tags"]]
    
    # Create Dataset objects
    train_dataset = Dataset.from_dict(train_data)
    test_dataset = Dataset.from_dict(test_data)
    
    print(f"Model configured for {len(label_list)} labels.")

    def tokenize_and_align_labels(examples):
        tokenized_inputs = tokenizer(examples["tokens"], truncation=True, is_split_into_words=True, padding=False)

        labels = []
        for i, label in enumerate(examples["ner_tags"]):
            word_ids = tokenized_inputs.word_ids(batch_index=i)
            previous_word_idx = None
            label_ids = []
            for word_idx in word_ids:
                if word_idx is None:
                    label_ids.append(-100)
                elif word_idx != previous_word_idx:
                    label_ids.append(label[word_idx])
                else:
                    label_ids.append(-100)
                previous_word_idx = word_idx
            labels.append(label_ids)
        tokenized_inputs["labels"] = labels
        return tokenized_inputs

    print("Tokenizing dataset...")
    tokenized_train = train_dataset.map(tokenize_and_align_labels, batched=True, remove_columns=train_dataset.column_names)
    tokenized_test = test_dataset.map(tokenize_and_align_labels, batched=True, remove_columns=test_dataset.column_names)
    print("Dataset tokenized.")

    # Set up training arguments with Apple Silicon optimizations
    training_args = TrainingArguments(
        output_dir="./results",
        eval_strategy="epoch",
        learning_rate=2e-5,
        per_device_train_batch_size=16,
        per_device_eval_batch_size=16,
        num_train_epochs=3,
        weight_decay=0.01,
        use_mps_device=torch.backends.mps.is_available(),  # Enable MPS for Apple Silicon
        fp16=False,  # MPS doesn't support fp16, use fp32
        dataloader_num_workers=0,  # MPS works best with 0 workers
        logging_steps=50,
        save_strategy="epoch",
    )

    # Data collator for dynamic padding
    data_collator = DataCollatorForTokenClassification(tokenizer)

    # Initialize the Trainer
    trainer = Trainer(
        model=model,
        args=training_args,
        train_dataset=tokenized_train,
        eval_dataset=tokenized_test,
        data_collator=data_collator,
    )

    # Fine-tune the model
    print("Starting fine-tuning...")
    trainer.train()
    print("Fine-tuning complete.")

    # Save the fine-tuned model
    print("Saving fine-tuned model...")
    model.save_pretrained("./model")
    tokenizer.save_pretrained("./model")
    print("Model saved to './model'")

if __name__ == "__main__":
    print("Script entry point reached.")
    main()
