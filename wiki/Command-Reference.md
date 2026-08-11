# Command Reference

## `:BuffersList`

Opens the popup file-buffer picker.

### Display path labels

Rows show the buffer file path with prefix rewriting in this order:

1. If a `.git` directory is found in parent directories, `getcwd()` starts with that project-root path, and the file path starts with `getcwd()`, the `getcwd()` prefix is replaced with `$CWD`.
2. Otherwise, if a `.git` directory is found in parent directories, the project-root prefix is replaced with `$PROJECT`.
3. If no project root is found and the file is under the user home directory, the home prefix is replaced with `$HOME`.
4. Otherwise the full absolute path is shown.
