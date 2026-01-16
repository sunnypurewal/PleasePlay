import pyarrow.parquet as pq
import sys
import os

def inspect_parquet_efficiently(file_path):
    if not os.path.exists(file_path):
        print(f"Error: File '{file_path}' not found.")
        return

    print(f"Inspecting: {file_path}")
    
    try:
        # Open the parquet file
        parquet_file = pq.ParquetFile(file_path)
        
        print("\n--- Metadata ---")
        print(f"Number of row groups: {parquet_file.num_row_groups}")
        print(f"Total rows: {parquet_file.metadata.num_rows}")
        print(f"Total columns: {parquet_file.metadata.num_columns}")
        
        print("\n--- Schema ---")
        print(parquet_file.schema)
        
        # Read just the first row group (or a small chunk) to inspect data
        print("\n--- First 5 Rows (Sample) ---")
        # Reading the first 5 rows specifically
        table_sample = parquet_file.read_row_group(0).slice(0, 5)
        df_sample = table_sample.to_pandas()
        
        import pandas as pd
        pd.set_option('display.max_columns', None)
        pd.set_option('display.width', 1000)
        print(df_sample)

    except Exception as e:
        print(f"An error occurred: {e}")

if __name__ == "__main__":
    file_to_inspect = sys.argv[1] if len(sys.argv) > 1 else "song_song_2026-01-19T16-06_part0.parquet.gz"
    inspect_parquet_efficiently(file_to_inspect)