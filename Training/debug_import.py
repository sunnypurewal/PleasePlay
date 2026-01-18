import sys
import time

print("--- CoreMLTools Import Debugger ---", flush=True)

# 1. Test basic print functionality
print("Step 1: Basic print test... OK", flush=True)
time.sleep(1)

# 2. Attempt to import coremltools
print("\nStep 2: Attempting to import coremltools...", flush=True)
time.sleep(1)

try:
    import coremltools as ct
    print("✅ Step 2: Successfully imported coremltools.", flush=True)
    time.sleep(1)
    
    # 3. Print version
    print("\nStep 3: Checking coremltools version...", flush=True)
    time.sleep(1)
    if hasattr(ct, '__version__'):
        print(f"✅ Step 3: coremltools version: {ct.__version__}", flush=True)
    else:
        print("⚠️ Step 3: Could not determine coremltools version.", flush=True)
        
except ImportError as e:
    print(f"❌ FAILED on Step 2: Could not import coremltools.", flush=True)
    print(f"   Error: {e}", flush=True)
    print("   This suggests a problem with your Python environment or coremltools installation.", flush=True)
    sys.exit(1)
except Exception as e:
    print(f"❌ FAILED during import or version check:", flush=True)
    print(f"   Error: {e}", flush=True)
    print("   An unexpected error occurred. The library might be corrupted or have a startup issue.", flush=True)
    sys.exit(1)

time.sleep(1)
print("\n--- Debugger Finished ---", flush=True)
