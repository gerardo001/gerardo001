import subprocess
import sys
import shutil
import argparse

def run_command(command, output_file):
    with open(output_file, 'w', encoding='utf-8') as f:
        process = subprocess.run(command, shell=True, stdout=f, stderr=subprocess.PIPE, text=True)
        if process.returncode != 0:
            print(f"Error running command: {command}\n{process.stderr}", file=sys.stderr)

def open_with_notepadpp(*files):
    notepadpp_path = shutil.which("notepad++")
    if notepadpp_path:
        for file in files:
            subprocess.Popen([notepadpp_path, file])

def main():
    parser = argparse.ArgumentParser(description="Displays code review diffs between current branch and a base branch/commit.")
    parser.add_argument("OriginalBranch", nargs="?", default="origin/develop", help="Base branch or commit to compare against (default: origin/develop)")
    args = parser.parse_args()

    base = args.OriginalBranch

    run_command(f"git log {base}..HEAD --name-status --reverse", "Review_Summary.diff")
    run_command(f"git log {base}..HEAD -p --reverse", "Review_Log.diff")
    run_command(f"git diff {base}..HEAD -p --reverse", "Review_Diff.diff")

    open_with_notepadpp("Review_Summary.diff", "Review_Log.diff", "Review_Diff.diff")

if __name__ == "__main__":
    main()