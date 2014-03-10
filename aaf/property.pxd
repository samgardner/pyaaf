cimport lib
from .base cimport AAFBase, AAFObject

cdef class Property(AAFBase):
    cdef lib.IAAFProperty *ptr
    
cdef class PropertyValue(AAFBase):
    cdef lib.IAAFPropertyValue *ptr
    
cdef class PropertyItem(object):
    cdef Property prop
    cdef AAFObject parent
    
cdef class TaggedValue(AAFObject):
    cdef lib.IAAFTaggedValue *ptr
    
    