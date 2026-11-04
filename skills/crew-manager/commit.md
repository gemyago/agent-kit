# Follow this instruction to commit changes.

Use this instruction if the user references this file (e.g., with @commit.md).

* All commands should be run from a repo root.
* Commit all updated files if not otherwise specified. In this case use `git add .` from a repo root as a first step to stage all updated files.
* You maybe given a list of files to commit. If user requested to commit specific files, use `git add <file1> <file2> ...` to stage specific files only.
* When committing, make sure to provide a sensible message. Figure out the message from chat history.
* If no relevant chat history available, use `git diff --staged | head -n 1000` to understand changes and figure-out a sensible message.

Do **NOT** do any other verification or actions unrelated to this instruction. You **SHOULD** just commit the changes as specified here.
