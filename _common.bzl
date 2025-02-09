def remove_file_name_extension(name):
    if "." not in name:
        return name
    return ".".join(name.split(".")[:-1])

def get_py_module_name(label, filename):
    return ".".join([label.package, remove_file_name_extension(filename)]).replace("/", ".").replace("-", "_")
