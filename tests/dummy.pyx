from cpython.object cimport PyObject


cpdef size_t get_refcnt(obj):
    return (<PyObject*> obj).ob_refcnt
