
cdef class Mob(AAFObject):
    """Base Class for All Mob Objects
    """
    
    def __cinit__(self):
        self.iid = lib.IID_IAAFMob
        self.auid = lib.AUID_AAFMob
        self.ptr = NULL

    cdef lib.IUnknown **get_ptr(self):
        return <lib.IUnknown **> &self.ptr
    
    cdef query_interface(self, AAFBase obj = None):
        if obj is None:
            obj = self
        else:
            query_interface(obj.get_ptr(), <lib.IUnknown**>&self.ptr, lib.IID_IAAFMob)
            
        AAFObject.query_interface(self, obj)
            
    def __dealloc__(self):
        if self.ptr:
            self.ptr.Release()
            
    def slots(self):
        cdef MobSlotIter slot_iter = MobSlotIter.__new__(MobSlotIter)
        error_check(self.ptr.GetSlots(&slot_iter.ptr)) 
        slot_iter.root = self.root   
        return slot_iter
    
    def slot_at(self, lib.aafSlotID_t slotID):
        """slot_at(slotID)
        """
        for slot in self.slots():
            if slot.slotID == slotID:
                return slot
        raise IndexError("Invalid slot number: %d" % slotID)
    
    def insert_slot(self, lib.aafUInt32 index, MobSlot slot):
        """insert_slot(index, slot)
        Inserts the given slot into this mob at the given index.  All
        existing slots at the given and higher index will be moved up one
        index to accommodate.
        """
        error_check(self.ptr.InsertSlotAt(index, slot.slot_ptr))
        
    def append_slot(self, MobSlot slot not None):
        error_check(self.ptr.AppendSlot(slot.slot_ptr))
        
    def create_clip(self, slotID = None, length = None, start_time = None):
        """create_clip(slotID = None, length = None, start_time = None)
        """

        d = self.dictionary()
        
        if slotID is None:
            slotID = list(self.slots())[0].slotID
            
        source_slot = self.slot_at(slotID)
        
        if length is None:
            length = source_slot.segment.length
        
        if start_time is None:
            start_time = source_slot.origin
            
        cdef SourceRef source_ref = SourceRef(self.mobID, slotID, start_time)
        
        return d.create.SourceClip(source_slot.media_kind, length, source_ref)
        
    def append_new_timeline_slot(self, edit_rate, Segment seg, lib.aafSlotID_t slotID = 0, 
                                 slot_name = None, lib.aafPosition_t origin = 0):
        
        """append_new_timeline_slot(edit_rate, seg, slotID = 0, slot_name = None, origin = 0)
        
        Creates a new :class:`TimelineMobSlot` with the given property values and appends it to the :class:`Mob`
        """
        
        if not slot_name:
            slot_name = 'timeline slot %d' % slotID
        
        cdef TimelineMobSlot timeline = TimelineMobSlot.__new__(TimelineMobSlot)
        
        cdef lib.aafRational_t edit_rate_t
        
        fraction_to_aafRational(edit_rate, edit_rate_t)

        cdef AAFCharBuffer slot_name_buf = AAFCharBuffer(slot_name)
        
        error_check(self.ptr.AppendNewTimelineSlot(edit_rate_t,
                                                  seg.seg_ptr,
                                                  slotID,
                                                  slot_name_buf.get_ptr(),
                                                  origin,
                                                  &timeline.ptr
                                                  ))
        timeline.query_interface()
        timeline.root = self.root
        return timeline
    
    def append_comment(self, name not None, value not None):
        """append_comment(name, value)
        """
        
        cdef AAFCharBuffer name_buf = AAFCharBuffer(name)
        cdef AAFCharBuffer value_buf = AAFCharBuffer(value)

        error_check(self.ptr.AppendComment(name_buf.get_ptr(), value_buf.get_ptr() ))
    
    def comments(self):
        cdef TaggedValueIter tags = TaggedValueIter.__new__(TaggedValueIter)
        tags.root = self.root
        hr = self.ptr.GetComments(&tags.ptr)
        if hr == lib.AAFRESULT_PROP_NOT_PRESENT:
            return []
        else:
            error_check(hr)
        
        return tags
    def remove_comment_by_name(self, name not None):
        """remove_comment_by_name(name)
        """
        
        cdef TaggedValue tag
        
        for tag in self.comments():
            if tag.name == name:
                error_check(self.ptr.RemoveComment(tag.ptr))
                return
        raise KeyError("No comment with name: %s" % str(name))
    
    def remove_comment(self, TaggedValue tag not None):
        """remove_comment(tag)
        """
        error_check(self.ptr.RemoveComment(tag.ptr))
    
    def __richcmp__(x, y, int op):
        if op == 2:
            
            if isinstance(x, Mob):
                x = x.mobID
            
            if isinstance(y, Mob):
                y = y.mobID

            if str(x) == str(y):
                return True
            return False
        raise NotImplemented("richcmp %d not not Implemented" % op)
        
    def __repr__(self):
        name = self.name
        if name:
            return '<%s.%s %s %s at 0x%x>' % (
                self.__class__.__module__,
                self.__class__.__name__,
                name, str(self.mobID), 
                id(self),
                )
        else:
            return '<%s.%s %s at 0x%x>' % (
                self.__class__.__module__,
                self.__class__.__name__,
                str(self.mobID), 
                id(self),
                )
    
    property name:
        def __get__(self):
            for p in self.properties():
                if p.name == 'Name':
                    name = p.value
                    if name:
                        return name

            return None
        
        def __set__(self, value):
            cdef AAFCharBuffer name_buf = AAFCharBuffer(value)
            error_check(self.ptr.SetName(name_buf.get_ptr()))
            
    property nb_slots:
        def __get__(self):
            cdef lib.aafNumSlots_t nb_slots
            error_check(self.ptr.CountSlots(&nb_slots))
            return nb_slots
    property mobID:
        """
        The unique Mob ID associated with this mob. Get Returns MobID Object
        """
        def __get__(self):
            cdef lib.aafMobID_t mobID
            error_check(self.ptr.GetMobID(&mobID))
            cdef MobID mobID_obj = MobID()
            
            mobID_obj.mobID = mobID
            return mobID_obj
        
        def __set__(self, value):
            cdef MobID mobID_obj = MobID(value)
            error_check(self.ptr.SetMobID(mobID_obj.get_aafMobID_t()))
            
          