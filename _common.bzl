def make_label(label_string):
    if type(label_string) == "Label":
        return label_string

    if label_string.startswith(":"):
        label_string = "//" + native.package_name() + label_string
    elif not (label_string.startswith("//") or label_string.startswith("@")):
        label_string = "//" + native.package_name() + ":" + label_string

    if label_string.startswith("//"):
        label_string = native.repository_name() + label_string

    return Label(label_string)

def remove_file_name_extension(name):
    if "." not in name:
        return name
    return ".".join(name.split(".")[:-1])

def get_py_module_name(label, filename):
    return ".".join([label.package, remove_file_name_extension(filename)]).replace("/", ".").replace("-", "_")
