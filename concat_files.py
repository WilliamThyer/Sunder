def concat_python_files(output_file, *input_files):
    """
    Concatenate the contents of multiple Python files into a single file.
    Each file's content is separated by a header line: --- FILENAME ---
    
    :param output_file: Name of the output Python file to write to.
    :param input_files: One or more Python files to concatenate.
    """
    with open(output_file, 'w', encoding='utf-8') as outfile:
        for py_file in input_files:
            # Write the separator with the file name
            outfile.write(f"--- {py_file} ---\n\n")
            
            # Read and write the file content
            with open(py_file, 'r', encoding='utf-8') as infile:
                outfile.write(infile.read())
                outfile.write("\n\n")
                
    print(f"Concatenated {len(input_files)} file(s) into '{output_file}'.")

import os
if __name__ == '__main__':
    output_file = os.environ.get('OUTPUT_FILE', 'output.py')
    input_files = os.environ.get('INPUT_FILES', 'input.py').split(',')
    concat_python_files(output_file, *input_files)
