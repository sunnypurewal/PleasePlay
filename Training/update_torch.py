
import subprocess
import sys

def run_pip(command):
    subprocess.check_call([sys.executable, "-m", "pip"] + command)

run_pip(["uninstall", "-y", "torch"])
run_pip(["install", "torch==2.7.0"])
