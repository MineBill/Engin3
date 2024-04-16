from cxxheaderparser.simple import parse_string
import re
import subprocess
import os
import platform

def typedef_remove_by_name(remove_name):
    indices = []
    i = 0
    for td in typedef_list:
        if hasattr(td.type,"ptr_to"):
            i += 1
            continue
    #TODO(What to do with FUnction ptr and vtable)
    #skip vtables but and function pointers for now
        for tds in td.type.typename.segments:
            if hasattr(tds,"name") == False:
                continue
            if remove_name == tds.name:
                indices.append(i)
                
        i += 1
    for index in indices:
        typedef_list.pop(index)
        

def process_function_ptr(x):
    input_string = 'proc "c" ('
    i = 0
    
    for p in x.parameters:
        input_string += (f"{p.name}:")
        if hasattr(p.type,"ptr_to"):
            for fs in p.type.ptr_to.typename.segments:
                name = fs.name
                if name == "void":
                    input_string += ("rawptr")
                else:
                    input_string += (f"^{name}")
        elif hasattr(p.type,"array_of"):
            #for t in p.type.size.tokens:
            size = p.type.size.tokens[0].value
            if hasattr(p.type.array_of,'typename'):
                for fs in p.type.array_of.typename.segments:
                    input_string += (f"[{size}]{fs.name}")
        else:
            for s in p.type.typename.segments:
                input_string += (f"{s.name}")
                #print(p.type.typename)  
        if i != len(x.parameters) - 1:
            input_string += (",")
        i = i+1
    input_string += (")")
    #return type
    if hasattr(x.return_type,"ptr_to"):
        if hasattr(x.return_type.ptr_to,"ptr_to"):
            for s in x.return_type.ptr_to.ptr_to.typename.segments:
                #denotes a multipointer or pointer to a pointer
                input_string += (f"->[^]{s.name}")
        else:
            for s in x.return_type.ptr_to.typename.segments:
                name = s.name
                if name == "void":
                    input_string += ("->rawptr")
                else:
                    input_string += (f"->^{name}")
                #input_string += (f"->^{s.name}")

    else:
        for s in x.return_type.typename.segments:
            name = s.name
            if name == "void":
                input_string += ("")
            else:
                input_string += (f"->{s.name}")

    return input_string


def process_function(x):
   # if x.has_body:
    #print("nothing")
    input_string = ""
    if x.has_body == False:
        #print(x.name)
        for s in x.name.segments:
            input_string += (f" {s.name}:: proc(")
        i = 0
        for p in x.parameters:
            input_string += (f"{p.name}:")
            if hasattr(p.type,"ptr_to"):
                for fs in p.type.ptr_to.typename.segments:
                    name = fs.name
                    if name == "void":
                        input_string += ("rawptr")
                    else:
                        input_string += (f"^{name}")
            elif hasattr(p.type,"array_of"):
                #for t in p.type.size.tokens:
                size = p.type.size.tokens[0].value
                if hasattr(p.type.array_of,'typename'):
                    for fs in p.type.array_of.typename.segments:
                        ptr = ""
                        if "out_" in p.name or "in_" in p.name:
                            ptr = "^"
                        input_string += (f"{ptr}[{size}]{fs.name}")
            else:
                for s in p.type.typename.segments:
                    input_string += (f"{s.name}")
                    #print(p.type.typename)  
            if i != len(x.parameters) - 1:
                input_string += (",")
            i = i+1
        input_string += (")")
        #return type
        if hasattr(x.return_type,"ptr_to"):
            if hasattr(x.return_type.ptr_to,"ptr_to"):
                 for s in x.return_type.ptr_to.ptr_to.typename.segments:
                #denotes a multipointer or pointer to a pointer
                    input_string += (f"->[^]{s.name}")
            else:
                for s in x.return_type.ptr_to.typename.segments:
                    name = s.name
                    if name == "void":
                        input_string += ("->rawptr")
                    else:
                        input_string += (f"->^{name}")
                    #input_string += (f"->^{s.name}")
        
        else:
            for s in x.return_type.typename.segments:
                name = s.name
                if name == "void":
                    input_string += ("")
                else:
                    input_string += (f"->{s.name}")
    input_string += ("---\n")
    return input_string
     
def process_struct(x,parent,input_string):
    final_name = ""
    for s in x.class_decl.typename.segments:
        if hasattr(s,"id"):#is anonymous
            id = s.id
            id_found = False
            if parent == None:
                continue
            for f in parent.fields:
                #for sf in f.type.segments:
                if hasattr(f.type,"typename") and hasattr(f.type.typename,"segments"):
                    for seg in f.type.typename.segments:
                    #if hasattr(f.type.typename.segments,"id"):
                   # if hasattr(f.type.typename.segments,"id"):
                        if hasattr(seg,"id") and seg.id == id:
                            input_string += (f"{f.name} : struct")
                            final_name = f.name
                            input_string += ("{\n")
                            id_found = True
            if id_found == False:
                input_string += ("using _ : struct{\n")
        else:
            input_string += (f"{s.name} :: struct")
            final_name = s.name
            input_string += ("{\n")
        for f in x.fields:
            #nested struct
            if hasattr(f.type,"typename") and hasattr(f.type.typename,"classkey") and f.type.typename.classkey != None:
                input_string += "\n"
                field_id = f.type.typename.segments[0].id
                for ns in x.classes:
                    class_id = ns.class_decl.typename.segments[0].id
                    if field_id == class_id:
                        new_string = ""
                        new_string += process_struct(ns,x,new_string)
                        input_string += new_string
            #pointers and function pointers
            elif hasattr(f.type,"ptr_to"):
                input_string += (f" {f.name} : ")
                if hasattr(f.type.ptr_to,"return_type") or hasattr(f.type,"parameters"):
                    #get the function signature of function pointer
                    #input_string += ("Function type,")
                    input_string += process_function_ptr(f.type.ptr_to)
                    input_string += ","
                    
                else:
                    for fs in f.type.ptr_to.typename.segments:
                        if fs.name == "void":
                            input_string += (f"rawptr,\n")
                        else:
                            input_string += (f"^{fs.name},\n")
                input_string += "\n"
            #array types          
            elif hasattr(f.type, 'array_of'):
                input_string += (f" {f.name} : ")
                if hasattr(f.type.array_of,'typename'):
                    size = f.type.size.tokens[0].value
                    for fs in f.type.array_of.typename.segments:
                        input_string += (f"[{size}]{fs.name},")
                elif hasattr(f.type.array_of,"ptr_to"):
                    size = f.type.size.tokens[0].value
                    for fs in f.type.array_of.ptr_to.typename.segments:
                        name = ""
                        if fs.name == "void":
                            name = "rawptr"
                        else:
                            name = fs.name
                        input_string += (f"[{size}]{name},")        
                if hasattr(f.type.array_of,"array_of"):
                    for fs in f.type.array_of.array_of.typename.segments:
                        inner_size = f.type.size.tokens[0].value
                        outer_size = f.type.array_of.size.tokens[0].value
                        input_string += (f"[{inner_size}][{outer_size}]{fs.name},")
                        input_string += (f"\n")
                input_string += "\n"  
            #basics
            else:
                input_string += (f" {f.name} : ")
                for fs in f.type.typename.segments:
                    input_string += (f"{fs.name},")
                input_string += "\n"
                
    if parent == None:
        input_string+= ("}\n\n")
    else:
        input_string += ("},\n")
    
    typedef_remove_by_name(final_name)
    return input_string
def extract_first_words(input_string,typedef_list):
    # Use a regular expression to find the first words separated by underscores
    #match = re.match(r'^\w+', input_string)
    # Remove underscores, replace the prefix, and capitalize words
    input_string = input_string.replace('JOLT_','')
    input_string = input_string.replace('_', ' ').title().replace(' ', '')

    for td in typedef_list:
        #match = re.match(r'^\w+', input_string)
        found = input_string in td.name
        if found == True:
            break
        

    if match:
        return match.group()
    else:
        return None

def process_enum(x,typedef_list):
    input_string = ""
    final_name = ""
    for s in x.typename.segments:
        if hasattr(s,"id"):
            #anon
            a = 0#do nothing
            #first_val = x.values[0]
            #print(extract_first_words(first_val.name)," :: enum{")
            #extracted_name = extract_first_words(first_val.name,typedef_list)
            
            #input_string += ("%s :: enum{\n" % final_name)
            return ""
        else:
            final_name = s.name
            input_string += ("%s :: enum{\n" % final_name)
        
        
        typedef_remove_by_name(final_name)
    for v in x.values:
        if hasattr(v.value,"tokens") and len(v.value.tokens) > 0:
            input_string += (f" {v.name} = {v.value.tokens[0].value},\n")
        else:
            input_string += (" %s,\n" % v.name)
            
    input_string += ("}\n") 
    return input_string


# Call preprocess for jolt_bind.h
subprocess.run(["python", "jolt_preprocess.py"])
# Read the content of the C++ file
with open("jolt_bind_pp.h", 'r') as file:
    content = file.read()

jolt_odin_output = ""
parsed_data = parse_string(content)

jolt_odin_output += ("package jolt\n")
jolt_odin_output += ('import "core:c"\n')
jolt_odin_output += ('import m "core:math/linalg/hlsl"\n')

jolt_odin_output += """
when ODIN_OS == .Windows {
    foreign import Jolt {
        "system:Kernel32.lib",
        "system:Gdi32.lib",
        "build/jolt_bind.lib",
    }
} else when ODIN_OS == .Linux {
    @(extra_linker_flags="-lstdc++")
    foreign import Jolt {
        "build/jolt_bind.a",
    }
}else when ODIN_OS == .Darwin{
    @(extra_linker_flags="-lstdc++")
    foreign import Jolt {
        "build/jolt_bind.a",
    }
}
"""

jolt_odin_output += ('\n\n\n')

enum_output = ""          
typedef_list = parsed_data.namespace.typedefs

for x in parsed_data.namespace.enums:
    enum_output += process_enum(x,typedef_list)
jolt_odin_output += enum_output

generated_typedef_enum_list = []
#find enums mathcing typdefs
for td in typedef_list:
    if hasattr(td.type,"ptr_to"):
         continue
    if td.type.typename.classkey != None:
        continue
    #match = re.match(r'^\w+', input_string)
    break_outer_loop = False
    for x in parsed_data.namespace.enums:
        #for s in x.typename.segments:
        s = x.typename.segments[0]
        if hasattr(s,"id"):
            #anon
            input_string = x.values[0].name
            td_name = td.name.replace('JOLT_','')
            input_string = input_string.replace('JOLT_','')
            input_string = input_string.replace('_', ' ').title().replace(' ', '')
            found = False
            if td_name.lower() in input_string.lower():
                jolt_odin_output += ("%s :: enum %s{\n" % (td_name,td.type.typename.segments[0].name))
                found = True
                generated_typedef_enum_list.append(td_name)
            #input_string += ("%s :: enum{\n" % final_name)
            if found == False:
                continue
            for v in x.values:
                if hasattr(v.value,"tokens") and len(v.value.tokens) > 0:
                    jolt_odin_output += (f" {v.name} = {v.value.tokens[0].value},\n")
                else:
                    jolt_odin_output += (" %s,\n" % v.name)
            jolt_odin_output += ("}\n") 
    
struct_output = ""
for x in parsed_data.namespace.classes:
    if x.class_decl.typename.classkey == "struct":
        struct_output = process_struct(x,None,struct_output)

jolt_odin_output += struct_output

#for x in parsed_data.namespace.typedefs:
for x in typedef_list:
    if hasattr(x.type,"ptr_to"):
        #jolt_odin_output += ("pointer")
        if  hasattr(x.type.ptr_to,"return_type") or hasattr(x.type,"parameters"):
                    #get the function signature of function pointer
                    #input_string += ("Function type,")
                    out = process_function_ptr(x.type.ptr_to)
                    #out = out.replace('"c"',"")
                    out = (f"{x.name} :: {out}\n")
                    
                    jolt_odin_output += out
    else:
        for s in x.type.typename.segments:
            #name = s.name
            #if hasattr(x.type.typename,"classkey"):\
            if x.type.typename.classkey != None:
                if x.name != "JOLT_Real":
                    jolt_odin_output += ("%s :: struct{}\n" % x.name)
            else:
                if x.name != "JOLT_Real":
                    
                    found = False
                    for entry in generated_typedef_enum_list:
                        test_entry = (f"JOLT_{entry}")
                        if test_entry == x.name:
                            found = True
                    if found == False:
                        jolt_odin_output += (f"{x.name} :: distinct {s.name} \n")

jolt_odin_output += "// Maximum amount of jobs to allow\n"
jolt_odin_output += "cMaxPhysicsJobs : u32 = 2048\n"

jolt_odin_output += "// Maximum amount of barriers to allow\n"
jolt_odin_output += "cMaxPhysicsBarriers : u32 = 8\n"


jolt_odin_output += '@(default_calling_convention="c")\n'
jolt_odin_output += '@(link_prefix="JOLT_")\n'
jolt_odin_output += ("foreign Jolt{\n")

function_output = ""
for x in parsed_data.namespace.functions:
    function_output += process_function(x) 
    #print(function_output)  
    
jolt_odin_output += function_output

jolt_odin_output += "}"
#print(jolt_odin_output)
#strip JOLT prefixes off everything
prev = jolt_odin_output
#get double or singel precision for JOLT_Real
for td in typedef_list:
    if td.name == "JOLT_Real":
        for s in td.type.typename.segments:
            single_or_double = s.name
if single_or_double == "float":
    jolt_odin_output = jolt_odin_output.replace("JOLT_Real", "float")
    jolt_odin_output = jolt_odin_output.replace("float", "c.float")
    
else:
    jolt_odin_output = jolt_odin_output.replace("JOLT_Real", "double")
    jolt_odin_output = jolt_odin_output.replace("float", "c.double")
    
jolt_odin_output = jolt_odin_output.replace("JOLT_", "")
prev = jolt_odin_output.replace('@(link_prefix="")\n','@(link_prefix="JOLT_")\n')
jolt_odin_output = prev

jolt_odin_output = jolt_odin_output.replace("size_t", "c.size_t")
jolt_odin_output = jolt_odin_output.replace("uint8_t", "c.uint8_t")
jolt_odin_output = jolt_odin_output.replace("uint16_t", "c.uint16_t")
jolt_odin_output = jolt_odin_output.replace("uint32_t", "c.uint32_t")
jolt_odin_output = jolt_odin_output.replace("uint64_t", "c.uint64_t")

jolt_odin_output = jolt_odin_output.replace("[3]c.float", "m.float3")
jolt_odin_output = jolt_odin_output.replace("[4]c.float", "m.float4")
jolt_odin_output = jolt_odin_output.replace("[16]c.float", "m.float4x4")

# Write the modified content back to the file
file_path = "jolt.odin"
with open(file_path, 'w') as file:
    file.write(jolt_odin_output)

 # Provide the path to your batch file
os_name = platform.system()
if os_name == 'Windows':
    # Set up the environment variables
    vs_path = r'C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build'
    os.environ['PATH'] = os.path.join(vs_path, 'vcvarsall.bat') + ' x64 && ' + os.environ['PATH']
    batch_file_path = r'jolt_bindings.bat'
    subprocess.run([batch_file_path], shell=True)
elif os_name == 'Linux':
    batch_file_path = r'./jolt_bindings.sh'
    subprocess.run([batch_file_path], shell=True)
