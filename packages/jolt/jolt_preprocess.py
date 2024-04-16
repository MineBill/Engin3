from io import StringIO

def process_header(header_path):
    from pcpp import Preprocessor, OutputDirective, Action
    class PassThruPreprocessor(Preprocessor):
            def on_include_not_found(self,is_malformed,is_system_include,curdir,includepath):
                raise OutputDirective(Action.IgnoreAndPassThrough)

            #def on_unknown_macro_in_defined_expr(self,tok):
            #    return None  # Pass through as expanded as possible
                
            #def on_unknown_macro_in_expr(self,ident):
            #    return None  # Pass through as expanded as possible
                
            #def on_unknown_macro_function_in_expr(self,ident):
            #    return None  # Pass through as expanded as possible
                
            #def on_directive_handle(self,directive,toks,ifpassthru,precedingtoks):
            #    super(PassThruPreprocessor, self).on_directive_handle(directive,toks,ifpassthru,precedingtoks)
            #    return None  # Pass through where possible

            #def on_directive_unknown(self,directive,toks,ifpassthru,precedingtoks):
            #    if directive.value == 'error' or directive.value == 'warning':
            #        super(PassThruPreprocessor, self).on_directive_unknown(directive,toks,ifpassthru,precedingtoks)
                # Pass through
            #    raise OutputDirective(Action.IgnoreAndPassThrough)                

            def on_comment(self,tok):
                # Pass through
                return True
    # Read the content of the C++ file
    with open(header_path, 'r') as file:
        content = file.read()
    # Create a Preprocessor instance
    pp = PassThruPreprocessor()
    #pp = pcpp.Preprocessor()
    #pp.define()
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
    print(preprocessed_text)
    # Write the modified content back to the file
    file_path = "jolt_bind_pp.h"
    with open(file_path, 'w') as file:
        file.write(preprocessed_text)


if __name__ == "__main__":
    # Specify the path to your header file
    header_file_path = "jolt_bind.h"

    # Process the header file
    process_header(header_file_path)
