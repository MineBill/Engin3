from io import StringIO
from pcpp import Preprocessor, OutputDirective, Action


def process_header(header_path):
    class PassThruPreprocessor(Preprocessor):
        def on_include_not_found(self,
                                 is_malformed,
                                 is_system_include,
                                 curdir, includepath):
            raise OutputDirective(Action.IgnoreAndPassThrough)

        def on_comment(self, tok):
            # Pass through
            return True
    # Read the content of the C++ file
    with open(header_path, 'r') as file:
        content = file.read()
    # Create a Preprocessor instance
    pp = PassThruPreprocessor()
    # pp = pcpp.Preprocessor()
    # pp.define()
    pp.line_directive = None
    # Parse the header file
    pp.parse(content)
    # Create a StringIO object to capture the preprocessed text
    output_buffer = StringIO()

    # Redirect the output to the buffer
    pp.write(output_buffer)

    # Get the preprocessed text from the buffer
    preprocessed_text = output_buffer.getvalue()

    # Output the preprocessed content
    # print(preprocessed_text)

    # Write the modified content back to the file
    file_path = "jolt_bind_pp.h"
    with open(file_path, 'w') as file:
        file.write(preprocessed_text)
