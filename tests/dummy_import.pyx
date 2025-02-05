from libcpp cimport bool

from .dummy cimport get_refcnt

cpdef bool has_refcnt(obj):
    return get_refcnt(obj) > 0

