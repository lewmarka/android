"use strict"

# pull in external modules
_ = require '../vendor/_.js'
gLong = require '../vendor/gLong.js'
util = require './util'
runtime = require './runtime'
{thread_name,JavaObject,JavaArray} = require './java_object'
exceptions = require './exceptions'
{log,debug,error,trace} = require './logging'
path = node?.path ? require 'path'
fs = node?.fs ? require 'fs'
{ReferenceClassData,PrimitiveClassData,ArrayClassData} = require './ClassData'

# things assigned to root will be available outside this module
root = exports ? this.natives = {}

get_property = (rs, jvm_key, _default = null) ->
  key = jvm_key.jvm2js_str()
  # jvm is already defined in release mode
  jvm = jvm ? require('./jvm')
  val = jvm.system_properties[key]
  if key is 'java.class.path'  # special case
    # the last path is actually the bootclasspath (vendor/classes/)
    return rs.init_string val[0...val.length-1].join ':'
  if val? then rs.init_string(val, true) else _default

# convenience function. idea taken from coffeescript's grammar
o = (fn_name, fn) -> fn_name: fn_name, fn: fn

trapped_methods =
  java:
    lang:
      ref:
        Reference: [
          o '<clinit>()V', (rs) -> # NOP, because we don't do our own GC and also this starts a thread?!?!?!
        ]
      String: [
          # trapped here only for speed
          o 'hashCode()I', (rs, _this) ->
              hash = _this.get_field rs, 'Ljava/lang/String;hash'
              if hash is 0
                offset = _this.get_field rs, 'Ljava/lang/String;offset'
                chars = _this.get_field(rs, 'Ljava/lang/String;value').array
                count = _this.get_field rs, 'Ljava/lang/String;count'
                for i in [0...count] by 1
                  hash = (hash * 31 + chars[offset++]) | 0
                _this.set_field rs, 'Ljava/lang/String;hash', hash
              hash
      ]
      System: [
        o 'loadLibrary(L!/!/String;)V', (rs) -> # NOP, because we don't support loading external libraries
        o 'adjustPropertiesForBackwardCompatibility(L!/util/Properties;)V', (rs) -> # NOP (apple-java specific)
        o 'getProperty(L!/!/String;)L!/!/String;', get_property
        o 'getProperty(L!/!/String;L!/!/String;)L!/!/String;', get_property
      ]
      Terminator: [
        o 'setup()V', (rs) -> # NOP, because we don't support threads
      ]
    util:
      concurrent:
        atomic:
          AtomicInteger: [
            o '<clinit>()V', (rs) -> #NOP
            o 'compareAndSet(II)Z', (rs, _this, expect, update) ->
                _this.set_field rs, 'Ljava/util/concurrent/atomic/AtomicInteger;value', update  # we don't need to compare, just set
                true # always true, because we only have one thread
          ]
    nio:
      Bits: [
        o 'byteOrder()L!/!/ByteOrder;', (rs) ->
            cls = rs.get_bs_class('Ljava/nio/ByteOrder;')
            cls.static_get rs, 'LITTLE_ENDIAN'
        o 'copyToByteArray(JLjava/lang/Object;JJ)V', (rs, srcAddr, dst, dstPos, length) ->
          unsafe_memcpy rs, null, srcAddr, dst, dstPos, length
      ]
      charset:
        Charset$3: [
          # this is trapped and NOP'ed for speed
          o 'run()L!/lang/Object;', (rs) -> null
        ]

doPrivileged = (rs, action) ->
  my_sf = rs.curr_frame()
  m = action.cls.method_lookup(rs, 'run()Ljava/lang/Object;')
  if m?
    rs.push action unless m.access_flags.static
    m.setup_stack(rs)
    my_sf.runner = ->
      rv = rs.pop()
      rs.meta_stack().pop()
      rs.push rv
    throw exceptions.ReturnException
  else
    rs.async_op (resume_cb, except_cb) ->
      action.cls.resolve_method rs, 'run()Ljava/lang/Object;',
        (->
          rs.meta_stack().push {}  # dummy
          resume_cb()),
        except_cb

stat_fd = (fd) ->
  try
    return fs.fstatSync fd
  catch e
    return null

stat_file = (fname, cb) ->
  fs.stat fname, (err, stat) ->
    if err?
      cb null
    else
      cb stat

# "Fast" array copy; does not have to check every element for illegal
# assignments. You can do tricks here (if possible) to copy chunks of the array
# at a time rather than element-by-element.
# This function *cannot* access any attribute other than 'array' on src due to
# the special case when src == dest (see code for System.arraycopy below).
arraycopy_no_check = (src, src_pos, dest, dest_pos, length) ->
  j = dest_pos
  for i in [src_pos...src_pos+length] by 1
    dest.array[j++] = src.array[i]
  # CoffeeScript, we are not returning an array.
  return

# "Slow" array copy; has to check every element for illegal assignments.
# You cannot do any tricks here; you must copy element by element until you
# have either copied everything, or encountered an element that cannot be
# assigned (which causes an exception).
# Guarantees: src and dest are two different reference types. They cannot be
#             primitive arrays.
arraycopy_check = (rs, src, src_pos, dest, dest_pos, length) ->
  j = dest_pos
  dest_comp_cls = dest.cls.get_component_class()
  for i in [src_pos...src_pos+length] by 1
    # Check if null or castable.
    if src.array[i] == null or src.array[i].cls.is_castable dest_comp_cls
      dest.array[j] = src.array[i]
    else
      rs.java_throw rs.get_bs_class('Ljava/lang/ArrayStoreException;'), 'Array element in src cannot be cast to dest array type.'
    j++
  # CoffeeScript, we are not returning an array.
  return

unsafe_memcpy = (rs, src_base, src_offset, dest_base, dest_offset, num_bytes) ->
  # XXX assumes base object is an array if non-null
  # TODO: optimize by copying chunks at a time
  num_bytes = num_bytes.toNumber()
  if src_base?
    src_offset = src_offset.toNumber()
    if dest_base?
      # both are java arrays
      arraycopy_no_check(src_base, src_offset, dest_base, dest_offset.toNumber(), num_bytes)
    else
      # src is an array, dest is a mem block
      dest_addr = rs.block_addr(dest_offset)
      if DataView?
        for i in [0...num_bytes] by 1
          rs.mem_blocks[dest_addr].setInt8(i, src_base.array[src_offset+i])
      else
        for i in [0...num_bytes] by 1
          rs.mem_blocks[dest_addr+i] = src_base.array[src_offset+i]
  else
    src_addr = rs.block_addr(src_offset)
    if dest_base?
      # src is a mem block, dest is an array
      dest_offset = dest_offset.toNumber()
      if DataView?
        for i in [0...num_bytes] by 1
          dest_base.array[dest_offset+i] = rs.mem_blocks[src_addr].getInt8(i)
      else
        for i in [0...num_bytes] by 1
          dest_base.array[dest_offset+i] = rs.mem_blocks[src_addr+i]
    else
      # both are mem blocks
      dest_addr = rs.block_addr(dest_offset)
      if DataView?
        for i in [0...num_bytes] by 1
          rs.mem_blocks[dest_addr].setInt8(i, rs.mem_blocks[src_addr].getInt8(i))
      else
        for i in [0...num_bytes] by 1
          rs.mem_blocks[dest_addr+i] = rs.mem_blocks[src_addr+i]

unsafe_compare_and_swap = (rs, _this, obj, offset, expected, x) ->
  actual = obj.get_field_from_offset rs, offset
  if actual == expected
    obj.set_field_from_offset rs, offset, x
    true
  else
    false

# avoid code dup among native methods
native_define_class = (rs, name, bytes, offset, len, loader, resume_cb, except_cb) ->
  raw_bytes = ((256+b)%256 for b in bytes.array[offset...offset+len])  # convert to raw bytes
  loader.define_class rs, util.int_classname(name.jvm2js_str()), raw_bytes, ((cdata)->resume_cb(cdata.get_class_object(rs))), except_cb

write_to_file = (rs, _this, bytes, offset, len, append) ->
  fd_obj = _this.get_field rs, 'Ljava/io/FileOutputStream;fd'
  fd = fd_obj.get_field rs, 'Ljava/io/FileDescriptor;fd'
  rs.java_throw rs.get_bs_class('Ljava/io/IOException;'), "Bad file descriptor" if fd is -1
  unless fd in [1, 2]
    # appends by default in the browser, not sure in actual node.js impl
    _this.$pos += fs.writeSync(fd, new Buffer(bytes.array), offset, len, _this.$pos)
    return
  rs.print util.chars2js_str(bytes, offset, len)
  if node?
    # For the browser implementation -- the DOM doesn't get repainted
    # unless we give the event loop a chance to spin.
    rs.async_op (cb) -> cb()

# Have a JavaClassLoaderObject and need its ClassLoader object? Use this method!
get_cl_from_jclo = (rs, jclo) -> if jclo? and jclo.$loader? then jclo.$loader else rs.get_bs_cl()

# helper function for stack trace natives (see java/lang/Throwable)
create_stack_trace = (rs, throwable) ->
  stacktrace = []
  # we don't want to include the stack frames that were created by
  # the construction of this exception
  cstack = rs.meta_stack()._cs.slice(1,-1)
  for sf in cstack when not (sf.native or sf.locals[0] is throwable)
    cls = sf.method.cls
    ln = -1
    unless throwable.cls.get_type() is 'Ljava/lang/NoClassDefFoundError;'
      if sf.method.access_flags.native
        source_file = 'Native Method'
      else
        source_file = cls.get_attribute('SourceFile')?.filename or 'unknown'
        table = sf.method.code?.get_attribute 'LineNumberTable'
        break unless table?
        # get the last line number before the stack frame's pc
        for i,row of table.entries when row.start_pc <= sf.pc
          ln = row.line_number
    else
      source_file = 'unknown'
    stacktrace.push new JavaObject rs, rs.get_bs_class('Ljava/lang/StackTraceElement;'), {
      'Ljava/lang/StackTraceElement;declaringClass': rs.init_string util.ext_classname cls.get_type()
      'Ljava/lang/StackTraceElement;methodName': rs.init_string(sf.method.name ? 'unknown')
      'Ljava/lang/StackTraceElement;fileName': rs.init_string source_file
      'Ljava/lang/StackTraceElement;lineNumber': ln
    }
  return stacktrace.reverse()

native_methods =
  org:
    js:
      JsSystem: [
        o 'javascriptAlert(Ljava/lang/String;)V', (rs, message) ->
            alert(message.jvm2js_str())
        o 'exec(Ljava/lang/String;)V', (rs, message) ->
            alert(message.jvm2js_str())
      ]

  java:
    lang:
      Class: [
        o 'getPrimitiveClass(L!/!/String;)L!/!/!;', (rs, jvm_str) ->
            type_desc = util.typestr2descriptor jvm_str.jvm2js_str()
            prim_cls = rs.get_bs_class type_desc
            return prim_cls.get_class_object(rs)
        o 'getClassLoader0()L!/!/ClassLoader;', (rs, _this) ->
            # The bootstrap classloader is represented as 'null', which is OK
            # according to the spec.
            loader = _this.$cls.loader
            return loader.loader_obj if loader.loader_obj?
            return null
        o 'desiredAssertionStatus0(L!/!/!;)Z', (rs) -> false # we don't need no stinkin asserts
        o 'getName0()L!/!/String;', (rs, _this) ->
            rs.init_string(_this.$cls.toExternalString())
        o 'forName0(L!/!/String;ZL!/!/ClassLoader;)L!/!/!;', (rs, jvm_str, initialize, loader) ->
            classname = util.int_classname jvm_str.jvm2js_str()
            unless util.verify_int_classname classname
              rs.java_throw rs.get_bs_class('Ljava/lang/ClassNotFoundException;'), classname
            loader = get_cl_from_jclo rs, loader
            rs.async_op (resume_cb, except_cb) ->
              if initialize
                loader.initialize_class rs, classname, ((cls) ->
                  resume_cb cls.get_class_object(rs)
                ), except_cb, true
              else
                loader.resolve_class rs, classname, ((cls) ->
                  resume_cb cls.get_class_object(rs)
                ), except_cb, true
            return
        o 'getComponentType()L!/!/!;', (rs, _this) ->
            return null unless (_this.$cls instanceof ArrayClassData)

            # As this array type is loaded, the component type is guaranteed
            # to be loaded as well. No need for asynchronicity.
            return _this.$cls.get_component_class().get_class_object(rs)
        o 'getGenericSignature()Ljava/lang/String;', (rs, _this) ->
            sig = _this.$cls.get_attribute('Signature')?.sig
            if sig? then rs.init_string sig else null
        o 'getProtectionDomain0()Ljava/security/ProtectionDomain;', (rs, _this) -> null
        o 'isAssignableFrom(L!/!/!;)Z', (rs, _this, cls) ->
            cls.$cls.is_castable _this.$cls
        o 'isInterface()Z', (rs, _this) ->
            return false unless _this.$cls instanceof ReferenceClassData
            _this.$cls.access_flags.interface
        o 'isInstance(L!/!/Object;)Z', (rs, _this, obj) ->
            obj.cls.is_castable _this.$cls
        o 'isPrimitive()Z', (rs, _this) ->
            _this.$cls instanceof PrimitiveClassData
        o 'isArray()Z', (rs, _this) ->
            _this.$cls instanceof ArrayClassData
        o 'getSuperclass()L!/!/!;', (rs, _this) ->
            return null if _this.$cls instanceof PrimitiveClassData
            cls = _this.$cls
            if cls.access_flags.interface or not cls.get_super_class()?
              return null
            return cls.get_super_class().get_class_object(rs)
        o 'getDeclaredFields0(Z)[Ljava/lang/reflect/Field;', (rs, _this, public_only) ->
            fields = _this.$cls.get_fields()
            fields = (f for f in fields when f.access_flags.public) if public_only
            base_array = []
            rs.async_op (resume_cb, except_cb) ->
              i = -1
              fetch_next_field = () ->
                i++
                if i < fields.length
                  f = fields[i]
                  f.reflector(rs, ((jco)->base_array.push(jco); fetch_next_field()), except_cb)
                else
                  resume_cb new JavaArray(rs, rs.get_bs_class('[Ljava/lang/reflect/Field;'), base_array)

              fetch_next_field()
            return
        o 'getDeclaredMethods0(Z)[Ljava/lang/reflect/Method;', (rs, _this, public_only) ->
            methods = _this.$cls.get_methods()
            methods = (m for sig, m of methods when sig[0] != '<' and (m.access_flags.public or not public_only))

            base_array = []
            rs.async_op (resume_cb, except_cb) ->
              i = -1
              fetch_next_method = () ->
                i++
                if i < methods.length
                  m = methods[i]
                  m.reflector(rs, false, ((jco)->base_array.push(jco); fetch_next_method()), except_cb)
                else
                  resume_cb new JavaArray(rs, rs.get_bs_class('[Ljava/lang/reflect/Method;'), base_array)

              fetch_next_method()
            return
        o 'getDeclaredConstructors0(Z)[Ljava/lang/reflect/Constructor;', (rs, _this, public_only) ->
            methods = _this.$cls.get_methods()
            methods = (m for sig, m of methods when m.name is '<init>')
            methods = (m for m in methods when m.access_flags.public) if public_only
            ctor_array_cdata = rs.get_bs_class('[Ljava/lang/reflect/Constructor;')
            base_array = []
            rs.async_op (resume_cb, except_cb) ->
              i = -1
              fetch_next_method = () ->
                i++
                if i < methods.length
                  m = methods[i]
                  m.reflector(rs, true, ((jco)->base_array.push(jco); fetch_next_method()), except_cb)
                else
                  resume_cb new JavaArray(rs, ctor_array_cdata, base_array)

              fetch_next_method()
            return
        o 'getInterfaces()[L!/!/!;', (rs, _this) ->
            cls = _this.$cls
            ifaces = cls.get_interfaces()
            iface_objs = (iface.get_class_object(rs) for iface in ifaces)
            new JavaArray rs, rs.get_bs_class('[Ljava/lang/Class;'), iface_objs
        o 'getModifiers()I', (rs, _this) -> _this.$cls.access_byte
        o 'getRawAnnotations()[B', (rs, _this) ->
            cls = _this.$cls
            annotations = cls.get_attribute 'RuntimeVisibleAnnotations'
            return new JavaArray rs, rs.get_bs_class('[B'), annotations.raw_bytes if annotations?
            for sig,m of cls.get_methods()
              annotations = m.get_attribute 'RuntimeVisibleAnnotations'
              return new JavaArray rs, rs.get_bs_class('[B'), annotations.raw_bytes if annotations?
            null
        o 'getConstantPool()Lsun/reflect/ConstantPool;', (rs, _this) ->
            cls = _this.$cls
            new JavaObject rs, rs.get_bs_class('Lsun/reflect/ConstantPool;'), {'Lsun/reflect/ConstantPool;constantPoolOop': cls.constant_pool}
        o 'getEnclosingMethod0()[L!/!/Object;', (rs, _this) ->
            return null unless _this.$cls instanceof ReferenceClassData
            cls = _this.$cls
            em = cls.get_attribute 'EnclosingMethod'
            return null unless em?
            enc_cls = cls.loader.get_resolved_class(em.enc_class).get_class_object(rs)
            if em.enc_method?
              enc_name = rs.init_string(em.enc_method.name)
              enc_desc = rs.init_string(em.enc_method.type)
            else
              enc_name = null
              enc_desc = null
            # array w/ 3 elements:
            # - the immediately enclosing class (java/lang/Class)
            # - the immediately enclosing method or constructor's name (can be null). (String)
            # - the immediately enclosing method or constructor's descriptor (null iff name is). (String)
            new JavaArray rs, rs.get_bs_class('[Ljava/lang/Object;'), [enc_cls, enc_name, enc_desc]
        o 'getDeclaringClass()L!/!/!;', (rs, _this) ->
            return null unless _this.$cls instanceof ReferenceClassData
            cls = _this.$cls
            icls = cls.get_attribute 'InnerClasses'
            return null unless icls?
            my_class = _this.$cls.get_type()
            for entry in icls.classes when entry.outer_info_index > 0
              name = cls.constant_pool.get(entry.inner_info_index).deref()
              continue unless name is my_class
              # XXX(jez): this assumes that the first enclosing entry is also
              # the immediate enclosing parent, and I'm not 100% sure this is
              # guaranteed by the spec
              declaring_name = cls.constant_pool.get(entry.outer_info_index).deref()
              return cls.loader.get_resolved_class(declaring_name).get_class_object(rs)
            return null
        o 'getDeclaredClasses0()[L!/!/!;', (rs, _this) ->
            ret = new JavaArray rs, rs.get_bs_class('[Ljava/lang/Class;'), []
            return ret unless _this.$cls instanceof ReferenceClassData
            cls = _this.$cls
            my_class = _this.$cls.get_type()
            iclses = cls.get_attributes 'InnerClasses'
            return ret if iclses.length is 0
            flat_names = []
            for icls in iclses
              for c in icls.classes when c.outer_info_index > 0
                enclosing_name = cls.constant_pool.get(c.outer_info_index).deref()
                continue unless enclosing_name is my_class
                flat_names.push cls.constant_pool.get(c.inner_info_index).deref()
            rs.async_op (resume_cb, except_cb) ->
              i = -1
              fetch_next_jco = () ->
                i++
                if i < flat_names.length
                  name = flat_names[i]
                  cls.loader.resolve_class(rs, name, ((cls)->ret.array.push cls.get_class_object(rs); fetch_next_jco()), except_cb)
                else
                  resume_cb ret
              fetch_next_jco()
            return
      ],
      # Fun Note: The bootstrap classloader object is represented by null.
      ClassLoader: [
        o 'findLoadedClass0(L!/!/String;)L!/!/Class;', (rs, _this, name) ->
            loader = get_cl_from_jclo rs, _this
            type = util.int_classname name.jvm2js_str()
            # Return JavaClassObject if loaded, or null otherwise.
            cls = loader.get_resolved_class type, true
            return if cls? then cls.get_class_object(rs) else null
        o 'findBootstrapClass(L!/!/String;)L!/!/Class;', (rs, _this, name) ->
            type = util.int_classname name.jvm2js_str()
            # This returns null in OpenJDK7, but actually can throw an exception
            # in OpenJDK6.
            rs.async_op (resume_cb, except_cb) ->
              rs.get_bs_cl().resolve_class rs, type, ((cls)->
                resume_cb cls.get_class_object(rs)
              ), except_cb, true
        o 'getCaller(I)L!/!/Class;', (rs, i) ->
            cls = rs.meta_stack().get_caller(i).method.cls
            return cls.get_class_object(rs)
        o 'defineClass1(L!/!/String;[BIIL!/security/ProtectionDomain;L!/!/String;Z)L!/!/Class;', (rs,_this,name,bytes,offset,len,pd,source,unused) ->
            loader = get_cl_from_jclo rs, _this
            rs.async_op (resume_cb, except_cb) ->
              native_define_class rs, name, bytes, offset, len, loader, resume_cb, except_cb
        o 'defineClass1(L!/!/String;[BIIL!/security/ProtectionDomain;L!/!/String;)L!/!/Class;', (rs,_this,name,bytes,offset,len,pd,source) ->
            loader = get_cl_from_jclo rs, _this
            rs.async_op (resume_cb, except_cb) ->
              native_define_class rs, name, bytes, offset, len, loader, resume_cb, except_cb
        o 'resolveClass0(L!/!/Class;)V', (rs, _this, cls) ->
            loader = get_cl_from_jclo rs, _this
            type = cls.$cls.get_type()
            return if loader.get_resolved_class(type, true)?
            # Ensure that this class is resolved.
            rs.async_op (resume_cb, except_cb) ->
              loader.resolve_class rs, type, (()->resume_cb()), except_cb, true
      ],
      Compiler: [
        o 'disable()V', (rs, _this) -> #NOP
        o 'enable()V', (rs, _this) -> #NOP
      ]
      Float: [
        o 'floatToRawIntBits(F)I', (rs, f_val) ->
            if Float32Array?
              f_view = new Float32Array [f_val]
              i_view = new Int32Array f_view.buffer
              return i_view[0]

            # Special cases!
            return 0 if f_val is 0
            # We map the infinities to JavaScript infinities. Map them back.
            return util.FLOAT_POS_INFINITY_AS_INT if f_val is Number.POSITIVE_INFINITY
            return util.FLOAT_NEG_INFINITY_AS_INT if f_val is Number.NEGATIVE_INFINITY
            # Convert JavaScript NaN to Float NaN value.
            return util.FLOAT_NaN_AS_INT if isNaN(f_val)

            # We have more bits of precision than a float, so below we round to
            # the nearest significand. This appears to be what the x86
            # Java does for normal floating point operations.

            sign = if f_val < 0 then 1 else 0
            f_val = Math.abs(f_val)
            # Subnormal zone!
            # (−1)^signbits×2^−126×0.significandbits
            # Largest subnormal magnitude:
            # 0000 0000 0111 1111 1111 1111 1111 1111
            # Smallest subnormal magnitude:
            # 0000 0000 0000 0000 0000 0000 0000 0001
            if f_val <= 1.1754942106924411e-38 and f_val >= 1.4012984643248170e-45
              exp = 0
              sig = Math.round((f_val/Math.pow(2,-126))*Math.pow(2,23))
              return (sign<<31)|(exp<<23)|sig
            # Regular FP numbers
            else
              exp = Math.floor(Math.log(f_val)/Math.LN2)
              sig = Math.round((f_val/Math.pow(2,exp)-1)*Math.pow(2,23))
              return (sign<<31)|((exp+127)<<23)|sig
        o 'intBitsToFloat(I)F', (rs, i_val) -> util.intbits2float(i_val)
      ]
      Double: [
        o 'doubleToRawLongBits(D)J', (rs, d_val) ->
            if Float64Array?
              d_view = new Float64Array [d_val]
              i_view = new Uint32Array d_view.buffer
              return gLong.fromBits i_view[0], i_view[1]

            # Fallback for older JS engines
            # Special cases
            return gLong.ZERO if d_val is 0
            if d_val is Number.POSITIVE_INFINITY
              # High bits: 0111 1111 1111 0000 0000 0000 0000 0000
              #  Low bits: 0000 0000 0000 0000 0000 0000 0000 0000
              return gLong.fromBits(0, 2146435072)
            else if d_val is Number.NEGATIVE_INFINITY
              # High bits: 1111 1111 1111 0000 0000 0000 0000 0000
              #  Low bits: 0000 0000 0000 0000 0000 0000 0000 0000
              return gLong.fromBits(0, -1048576)
            else if isNaN(d_val)
              # High bits: 0111 1111 1111 1000 0000 0000 0000 0000
              #  Low bits: 0000 0000 0000 0000 0000 0000 0000 0000
              return gLong.fromBits(0, 2146959360)

            sign = if d_val < 0 then (1 << 31) else 0
            d_val = Math.abs(d_val)

            # Check if it is a subnormal number.
            # (-1)s × 0.f × 2-1022
            # Largest subnormal magnitude:
            # 0000 0000 0000 1111 1111 1111 1111 1111
            # 1111 1111 1111 1111 1111 1111 1111 1111
            # Smallest subnormal magnitude:
            # 0000 0000 0000 0000 0000 0000 0000 0000
            # 0000 0000 0000 0000 0000 0000 0000 0001
            if d_val <= 2.2250738585072010e-308 and d_val >= 5.0000000000000000e-324
              exp = 0
              sig = gLong.fromNumber((d_val/Math.pow(2,-1022))*Math.pow(2,52))
            else
              exp = Math.floor(Math.log(d_val)/Math.LN2)
              # If d_val is close to a power of two, there's a chance that exp
              # will be 1 greater than it should due to loss of accuracy in the
              # log result.
              exp = exp-1 if d_val < Math.pow(2,exp)
              sig = gLong.fromNumber((d_val/Math.pow(2,exp)-1)*Math.pow(2,52))
              exp = (exp + 1023) << 20

            high_bits = sig.getHighBits() | sign | exp

            gLong.fromBits(sig.getLowBits(), high_bits)
        o 'longBitsToDouble(J)D', (rs, l_val) -> util.longbits2double(l_val.getHighBits(), l_val.getLowBitsUnsigned())
      ]
      Object: [
        o 'getClass()L!/!/Class;', (rs, _this) ->
            return _this.cls.get_class_object(rs)
        o 'hashCode()I', (rs, _this) ->
            # return the pseudo heap reference, essentially a unique id
            _this.ref
        o 'clone()L!/!/!;', (rs, _this) -> _this.clone(rs)
        o 'notify()V', (rs, _this) ->
            debug "TE(notify): on lock *#{_this.ref}"
            if (locker = rs.lock_refs[_this])?
              if locker isnt rs.curr_thread
                owner = thread_name rs, locker
                rs.java_throw rs.get_bs_class('Ljava/lang/IllegalMonitorStateException;'), "Thread '#{owner}' owns this monitor"
            if rs.waiting_threads[_this]?
              rs.waiting_threads[_this].shift()
        o 'notifyAll()V', (rs, _this) ->
            debug "TE(notifyAll): on lock *#{_this.ref}"
            if (locker = rs.lock_refs[_this])?
              if locker isnt rs.curr_thread
                owner = thread_name rs, locker
                rs.java_throw rs.get_bs_class('Ljava/lang/IllegalMonitorStateException;'), "Thread '#{owner}' owns this monitor"
            if rs.waiting_threads[_this]?
              rs.waiting_threads[_this] = []
        o 'wait(J)V', (rs, _this, timeout) ->
            unless timeout is gLong.ZERO
              error "TODO(Object::wait): respect the timeout param (#{timeout})"
            if (locker = rs.lock_refs[_this])?
              if locker isnt rs.curr_thread
                owner = thread_name rs, locker
                rs.java_throw rs.get_bs_class('Ljava/lang/IllegalMonitorStateException;'), "Thread '#{owner}' owns this monitor"
            rs.lock_refs[_this] = null
            rs.wait _this
      ]
      Package: [
        o 'getSystemPackage0(Ljava/lang/String;)Ljava/lang/String;', (rs, pkg_name_obj) ->
            pkg_name = pkg_name_obj.jvm2js_str()
            return if rs.get_bs_cl().does_package_exist(pkg_name) then pkg_name_obj else null
      ]
      ProcessEnvironment: [
        o 'environ()[[B', (rs) ->
            env_arr = []
            # convert to an array of strings of the form [key, value, key, value ...]
            for k, v of process.env
              env_arr.push new JavaArray rs, rs.get_bs_class('[B'), util.bytestr_to_array k
              env_arr.push new JavaArray rs, rs.get_bs_class('[B'), util.bytestr_to_array v
            new JavaArray rs, rs.get_bs_class('[[B'), env_arr
      ]
      reflect:
        Array: [
          o 'newArray(L!/!/Class;I)L!/!/Object;', (rs, _this, len) ->
              rs.heap_newarray _this.$cls.get_type(), len
          o 'getLength(Ljava/lang/Object;)I', (rs, arr) ->
              rs.check_null(arr).array.length
          o 'set(Ljava/lang/Object;ILjava/lang/Object;)V', (rs, arr, idx, val) ->
              my_sf = rs.curr_frame()
              array = rs.check_null(arr).array

              unless idx < array.length
                rs.java_throw rs.get_bs_class('Ljava/lang/ArrayIndexOutOfBoundsException;'), 'Tried to write to an illegal index in an array.'

              if (ccls = arr.cls.get_component_class()) instanceof PrimitiveClassData
                if val.cls.is_subclass rs.get_bs_class ccls.box_class_name()
                  ccname = ccls.get_type()
                  m = val.cls.method_lookup(rs, "#{util.internal2external[ccname]}Value()#{ccname}")
                  rs.push val
                  m.setup_stack rs
                  my_sf.runner = ->
                    array[idx] = if ccname in ['J', 'D'] then rs.pop2() else rs.pop()
                    rs.meta_stack().pop()
                  throw exceptions.ReturnException
              else if val.cls.is_subclass ccls
                array[idx] = val
                return

              illegal_exc = 'Ljava/lang/IllegalArgumentException;'
              if (ecls = rs.get_bs_class(illegal_exc, true))?
                rs.java_throw ecls, 'argument type mismatch'
              else
                rs.async_op (resume_cb, except_cb) ->
                  rs.get_cl().initialize_class rs, illegal_exc,
                    ((ecls) -> except_cb (-> rs.java_throw ecls, 'argument type mismatch')), except_cb
        ]
        Proxy: [
          o 'defineClass0(L!/!/ClassLoader;L!/!/String;[BII)L!/!/Class;', (rs,cl,name,bytes,offset,len) ->
              rs.async_op (success_cb, except_cb) ->
                native_define_class rs, name, bytes, offset, len, get_cl_from_jclo(rs, cl), success_cb, except_cb
        ]
      Runtime: [
        o 'availableProcessors()I', () -> 1
        o 'gc()V', (rs) ->
            # No universal way of forcing browser to GC, so we yield in hopes
            # that the browser will use it as an opportunity to GC.
            rs.async_op (cb) -> cb()
      ]
      SecurityManager: [
        o 'getClassContext()[Ljava/lang/Class;', (rs, _this) ->
            # return an array of classes for each method on the stack
            # starting with the current method and going up the call chain
            classes = []
            for sf in rs.meta_stack()._cs by -1  # have to get at the internals
              unless sf.native
                classes.push sf.method.cls.get_class_object(rs)
            new JavaArray rs, rs.get_bs_class('[Ljava/lang/Class;'), classes
      ]
      Shutdown: [
        o 'halt0(I)V', (rs, status) -> throw new exceptions.HaltException(status)
      ]
      StrictMath: [
        o 'acos(D)D', (rs, d_val) -> Math.acos(d_val)
        o 'asin(D)D', (rs, d_val) -> Math.asin(d_val)
        o 'atan(D)D', (rs, d_val) -> Math.atan(d_val)
        o 'atan2(DD)D', (rs, y, x) -> Math.atan2(y, x)
        o 'cos(D)D', (rs, d_val) -> Math.cos(d_val)
        o 'exp(D)D', (rs, d_val) -> Math.exp(d_val)
        o 'log(D)D', (rs, d_val) -> Math.log(d_val)
        o 'pow(DD)D', (rs, base, exp) -> Math.pow(base, exp)
        o 'sin(D)D', (rs, d_val) -> Math.sin(d_val)
        o 'sqrt(D)D', (rs, d_val) -> Math.sqrt(d_val)
        o 'tan(D)D', (rs, d_val) -> Math.tan(d_val)
        # these two are native in OpenJDK but not Apple-Java
        o 'floor(D)D', (rs, d_val) -> Math.floor(d_val)
        o 'ceil(D)D', (rs, d_val) -> Math.ceil(d_val)
      ]
      String: [
        o 'intern()L!/!/!;', (rs, _this) ->
            js_str = _this.jvm2js_str()
            unless (s = rs.string_pool.get(js_str))?
              s = rs.string_pool.set(js_str, _this)
            s
      ]
      System: [
        o 'arraycopy(L!/!/Object;IL!/!/Object;II)V', (rs, src, src_pos, dest, dest_pos, length) ->
            # Needs to be checked *even if length is 0*.
            if !src? or !dest?
              rs.java_throw rs.get_bs_class('Ljava/lang/NullPointerException;'), 'Cannot copy to/from a null array.'
            # Can't do this on non-array types. Need to check before I check bounds below, or else I'll get an exception.
            if !(src.cls instanceof ArrayClassData) or !(dest.cls instanceof ArrayClassData)
              rs.java_throw rs.get_bs_class('Ljava/lang/ArrayStoreException;'), 'src and dest arguments must be of array type.'
            # Also needs to be checked *even if length is 0*.
            if src_pos < 0 or (src_pos+length) > src.array.length or dest_pos < 0 or (dest_pos+length) > dest.array.length or length < 0
              # System.arraycopy requires IndexOutOfBoundsException, but Java throws an array variant of the exception in practice.
              rs.java_throw rs.get_bs_class('Ljava/lang/ArrayIndexOutOfBoundsException;'), 'Tried to write to an illegal index in an array.'
            # Special case; need to copy the section of src that is being copied into a temporary array before actually doing the copy.
            if src == dest
              src = {cls: src.cls, array: src.array.slice(src_pos, src_pos+length)}
              src_pos = 0

            if src.cls.is_castable dest.cls
              # Fast path
              arraycopy_no_check(src, src_pos, dest, dest_pos, length)
            else
              # Slow path
              # Absolutely cannot do this when two different primitive types, or a primitive type and a reference type.
              src_comp_cls = src.cls.get_component_class()
              dest_comp_cls = dest.cls.get_component_class()
              if (src_comp_cls instanceof PrimitiveClassData) or (dest_comp_cls instanceof PrimitiveClassData)
                rs.java_throw rs.get_bs_class('Ljava/lang/ArrayStoreException;'), 'If calling arraycopy with a primitive array, both src and dest must be of the same primitive type.'
              else
                # Must be two reference types.
                arraycopy_check(rs, src, src_pos, dest, dest_pos, length)
        o 'currentTimeMillis()J', (rs) -> gLong.fromNumber((new Date).getTime())
        o 'identityHashCode(L!/!/Object;)I', (rs, x) -> x?.ref ? 0
        o 'initProperties(L!/util/Properties;)L!/util/Properties;', (rs, props) -> rs.push null # return value should not be used
        o 'nanoTime()J', (rs) ->
            # we don't actually have nanosecond precision
            gLong.fromNumber((new Date).getTime()).multiply(gLong.fromNumber(1000000))
        o 'setIn0(L!/io/InputStream;)V', (rs, stream) ->
            sys = rs.get_bs_class 'Ljava/lang/System;'
            sys.static_put rs, 'in', stream
        o 'setOut0(L!/io/PrintStream;)V', (rs, stream) ->
            sys = rs.get_bs_class 'Ljava/lang/System;'
            sys.static_put rs, 'out', stream
        o 'setErr0(L!/io/PrintStream;)V', (rs, stream) ->
            sys = rs.get_bs_class 'Ljava/lang/System;'
            sys.static_put rs, 'err', stream
      ]
      Thread: [
        o 'currentThread()L!/!/!;', (rs) -> rs.curr_thread
        o 'setPriority0(I)V', (rs) -> # NOP
        o 'holdsLock(L!/!/Object;)Z', (rs, obj) -> rs.curr_thread is rs.lock_refs[obj]
        o 'isAlive()Z', (rs, _this) -> _this.$isAlive ? false
        o 'isInterrupted(Z)Z', (rs, _this, clear_flag) ->
            tmp = _this.$isInterrupted ? false
            _this.$isInterrupted = false if clear_flag
            tmp
        o 'interrupt0()V', (rs, _this) ->
            _this.$isInterrupted = true
            return if _this is rs.curr_thread
            debug "TE(interrupt0): interrupting #{thread_name rs, _this}"
            new_thread_sf = util.last _this.$meta_stack._cs
            new_thread_sf.runner = ->
              rs.java_throw rs.get_bs_class('Ljava/lang/InterruptedException;'), 'interrupt0 called'
            _this.$meta_stack.push {}  # dummy
            rs.yield _this
            throw exceptions.ReturnException
        o 'start0()V', (rs, _this) ->
            _this.$isAlive = true
            _this.$meta_stack = new runtime.CallStack()
            rs.thread_pool.push _this
            old_thread_sf = rs.curr_frame()
            debug "TE(start0): starting #{thread_name rs, _this} from #{thread_name rs, rs.curr_thread}"
            rs.curr_thread = _this
            new_thread_sf = rs.curr_frame()
            rs.push _this
            run_method = _this.cls.method_lookup(rs, 'run()V')
            thread_runner_sf = run_method.setup_stack(rs)
            new_thread_sf.runner = ->
              new_thread_sf.runner = null  # new_thread_sf is the fake SF at index 0
              _this.$isAlive = false
              debug "TE(start0): thread died: #{thread_name rs, _this}"
            old_thread_sf.runner = ->
              debug "TE(start0): thread resumed: #{thread_name rs, rs.curr_thread}"
              rs.meta_stack().pop()
            throw exceptions.ReturnException
        o 'sleep(J)V', (rs, millis) ->
            # sleep is a yield point, plus some fancy wakeup semantics
            rs.curr_thread.wakeup_time = (new Date).getTime() + millis.toNumber()
            rs.async_op (resume_cb) ->
              rs.choose_next_thread null, (next_thread) ->
                rs.yield next_thread
                resume_cb()
        o 'yield()V', (rs, _this) ->
            rs.async_op (resume_cb) ->
              rs.choose_next_thread null, (next_thread) ->
                rs.yield next_thread
                resume_cb()
      ]
      Throwable: [
        o 'fillInStackTrace()L!/!/!;', (rs, _this) ->
            strace = new JavaArray rs, rs.get_bs_class('[Ljava/lang/StackTraceElement;'), create_stack_trace(rs, _this)
            _this.set_field rs, 'Ljava/lang/Throwable;stackTrace', strace
            _this
        o 'getStackTraceDepth()I', (rs, _this) ->
            create_stack_trace(rs, _this).length
        o 'getStackTraceElement(I)L!/!/StackTraceElement;', (rs, _this, depth) ->
            create_stack_trace(rs, _this)[depth]
      ]
      UNIXProcess: [
        o 'forkAndExec([B[BI[BI[BZLjava/io/FileDescriptor;Ljava/io/FileDescriptor;Ljava/io/FileDescriptor;)I',
          (rs, _this, prog, argBlock) ->
            progname = util.chars2js_str(prog,0,prog.array.length)
            args = util.chars2js_str(argBlock,0,argBlock.array.length)
            rs.java_throw rs.get_bs_class('Ljava/lang/Error;'),
              "Doppio doesn't support forking processes. Command was: `#{progname} #{args}`"

      ]
    security:
      AccessController: [
        o 'doPrivileged(L!/!/PrivilegedAction;)L!/lang/Object;', doPrivileged
        o 'doPrivileged(L!/!/PrivilegedAction;L!/!/AccessControlContext;)L!/lang/Object;', doPrivileged
        o 'doPrivileged(L!/!/PrivilegedExceptionAction;)L!/lang/Object;', doPrivileged
        o 'doPrivileged(L!/!/PrivilegedExceptionAction;L!/!/AccessControlContext;)L!/lang/Object;', doPrivileged
        o 'getStackAccessControlContext()Ljava/security/AccessControlContext;', (rs) -> null
      ]
    sql:
      DriverManager: [
        o 'getCallerClassLoader()Ljava/lang/ClassLoader;', (rs) ->
          rv = rs.meta_stack().get_caller(1).method.cls.loader.loader_obj
          # The loader_obj of the bootstrap classloader is null.
          return if rv != undefined then rv else null
      ]
    io:
      Console: [
        o 'encoding()L!/lang/String;', -> null
        o 'istty()Z', -> true
      ]
      FileSystem: [
        o 'getFileSystem()L!/!/!;', (rs) ->
            # TODO: avoid making a new FS object each time this gets called? seems to happen naturally in java/io/File...
            my_sf = rs.curr_frame()
            cdata = rs.get_bs_class('Ljava/io/ExpiringCache;')
            cache1 = new JavaObject rs, cdata
            cache2 = new JavaObject rs, cdata
            cache_init = cdata.method_lookup(rs, '<init>()V')
            rs.push2 cache1, cache2
            cache_init.setup_stack(rs)
            my_sf.runner = ->
              cache_init.setup_stack(rs)
              my_sf.runner = ->
                # hack: don't use get_property if we don't want to make java/lang/String objects
                system_properties = (jvm ? require('./jvm')).system_properties
                rv = new JavaObject rs, rs.get_bs_class('Ljava/io/UnixFileSystem;'), {
                  'Ljava/io/UnixFileSystem;cache': cache1
                  'Ljava/io/UnixFileSystem;javaHomePrefixCache': cache2
                  'Ljava/io/UnixFileSystem;slash': system_properties['file.separator'].charCodeAt(0)
                  'Ljava/io/UnixFileSystem;colon': system_properties['path.separator'].charCodeAt(0)
                  'Ljava/io/UnixFileSystem;javaHome': rs.init_string system_properties['java.home'], true
                }
                rs.meta_stack().pop()
                rs.push rv
            throw exceptions.ReturnException
      ]
      FileOutputStream: [
        o 'open(L!/lang/String;)V', (rs, _this, fname) ->
            rs.async_op (resume_cb) ->
              fs.open fname.jvm2js_str(), 'w', (err, fd) ->
                fd_obj = _this.get_field rs, 'Ljava/io/FileOutputStream;fd'
                fd_obj.set_field rs, 'Ljava/io/FileDescriptor;fd', fd
                _this.$pos = 0
                resume_cb()
        o 'openAppend(Ljava/lang/String;)V', (rs, _this, fname) ->
            rs.async_op (resume_cb) ->
              fs.open fname.jvm2js_str(), 'a', (err, fd) ->
                fd_obj = _this.get_field rs, 'Ljava/io/FileOutputStream;fd'
                fd_obj.set_field rs, 'Ljava/io/FileDescriptor;fd', fd
                _this.$pos = (stat_fd fd).size
                resume_cb()
        o 'writeBytes([BIIZ)V', write_to_file  # OpenJDK version
        o 'writeBytes([BII)V', write_to_file   # Apple-java version
        o 'close0()V', (rs, _this) ->
            fd_obj = _this.get_field rs, 'Ljava/io/FileOutputStream;fd'
            fd = fd_obj.get_field rs, 'Ljava/io/FileDescriptor;fd'
            rs.async_op (resume_cb, except_cb) ->
              fs.close fd, (err) ->
                if err
                  except_cb -> rs.java_throw rs.get_bs_class('Ljava/io/IOException;'), err.message
                else
                  fd_obj.set_field rs, 'Ljava/io/FileDescriptor;fd', -1
                  resume_cb()
      ]
      FileInputStream: [
        o 'available()I', (rs, _this) ->
            fd_obj = _this.get_field rs, 'Ljava/io/FileInputStream;fd'
            fd = fd_obj.get_field rs, 'Ljava/io/FileDescriptor;fd'
            rs.java_throw rs.get_bs_class('Ljava/io/IOException;'), "Bad file descriptor" if fd is -1
            return 0 if fd is 0 # no buffering for stdin
            stats = fs.fstatSync fd
            stats.size - _this.$pos
        o 'read()I', (rs, _this) ->
            fd_obj = _this.get_field rs, 'Ljava/io/FileInputStream;fd'
            fd = fd_obj.get_field rs, 'Ljava/io/FileDescriptor;fd'
            rs.java_throw rs.get_bs_class('Ljava/io/IOException;'), "Bad file descriptor" if fd is -1
            unless fd is 0
              # this is a real file that we've already opened
              buf = new Buffer((fs.fstatSync fd).size)
              bytes_read = fs.readSync(fd, buf, 0, 1, _this.$pos)
              _this.$pos++
              return if bytes_read == 0 then -1 else buf.readUInt8(0)
            # reading from System.in, do it async
            rs.async_op (cb) ->
              rs.async_input 1, (byte) ->
                cb(if byte.length == 0 then -1 else byte[0])
        o 'readBytes([BII)I', (rs, _this, byte_arr, offset, n_bytes) ->
            fd_obj = _this.get_field rs, 'Ljava/io/FileInputStream;fd'
            fd = fd_obj.get_field rs, 'Ljava/io/FileDescriptor;fd'
            rs.java_throw rs.get_bs_class('Ljava/io/IOException;'), "Bad file descriptor" if fd is -1
            unless fd is 0
              # this is a real file that we've already opened
              pos = _this.$pos
              buf = new Buffer n_bytes
              # if at end of file, return -1.
              filesize = fs.fstatSync(fd).size
              if filesize > 0 and pos >= filesize-1
                return -1
              bytes_read = fs.readSync(fd, buf, 0, n_bytes, pos)
              # not clear why, but sometimes node doesn't move the file pointer,
              # so we do it here ourselves
              _this.$pos += bytes_read
              byte_arr.array[offset+i] = buf.readUInt8(i) for i in [0...bytes_read] by 1
              return if bytes_read == 0 and n_bytes isnt 0 then -1 else bytes_read
            # reading from System.in, do it async
            rs.async_op (cb) ->
              rs.async_input n_bytes, (bytes) ->
                byte_arr.array[offset+idx] = b for b, idx in bytes
                cb(bytes.length)
        o 'open(Ljava/lang/String;)V', (rs, _this, filename) ->
            filepath = filename.jvm2js_str()
            # TODO: actually look at the mode
            rs.async_op (resume_cb, except_cb) ->
              fs.open filepath, 'r', (e, fd) ->
                if e?
                  if e.code == 'ENOENT'
                    except_cb ()-> rs.java_throw rs.get_bs_class('Ljava/io/FileNotFoundException;'), "#{filepath} (No such file or directory)"
                  else
                    except_cb ()-> throw e
                else
                  fd_obj = _this.get_field rs, 'Ljava/io/FileInputStream;fd'
                  fd_obj.set_field rs, 'Ljava/io/FileDescriptor;fd', fd
                  _this.$pos = 0
                  resume_cb()
        o 'close0()V', (rs, _this) ->
            fd_obj = _this.get_field rs, 'Ljava/io/FileInputStream;fd'
            fd = fd_obj.get_field rs, 'Ljava/io/FileDescriptor;fd'
            rs.async_op (resume_cb, except_cb) ->
              fs.close fd, (err) ->
                if err
                  except_cb -> rs.java_throw rs.get_bs_class('Ljava/io/IOException;'), err.message
                else
                  fd_obj.set_field rs, 'Ljava/io/FileDescriptor;fd', -1
                  resume_cb()
        o 'skip(J)J', (rs, _this, n_bytes) ->
            fd_obj = _this.get_field rs, 'Ljava/io/FileInputStream;fd'
            fd = fd_obj.get_field rs, 'Ljava/io/FileDescriptor;fd'
            rs.java_throw rs.get_bs_class('Ljava/io/IOException;'), "Bad file descriptor" if fd is -1
            unless fd is 0
              bytes_left = fs.fstatSync(file).size - _this.$pos
              to_skip = Math.min(n_bytes.toNumber(), bytes_left)
              _this.$pos += to_skip
              return gLong.fromNumber(to_skip)
            # reading from System.in, do it async
            rs.async_op (cb) ->
              rs.async_input n_bytes.toNumber(), (bytes) ->
                # we don't care about what the input actually was
                cb gLong.fromNumber(bytes.length), null
      ]
      ObjectInputStream: [
        o 'latestUserDefinedLoader()Ljava/lang/ClassLoader;', (rs) ->
            # Returns the first non-null class loader (not counting class loaders
            #  of generated reflection implementation classes) up the execution stack,
            #  or null if only code from the null class loader is on the stack.
            null  # XXX: actually check for class loaders on the stack
      ]
      ObjectStreamClass: [
        o 'initNative()V', (rs) ->  # NOP
        o 'hasStaticInitializer(Ljava/lang/Class;)Z', (rs, cls) ->
            # check if cls has a <clinit> method
            return cls.$cls.get_method('<clinit>()V')?
      ]
      RandomAccessFile: [
        o 'open(Ljava/lang/String;I)V', (rs, _this, filename, mode) ->
            filepath = filename.jvm2js_str()
            # TODO: actually look at the mode
            rs.async_op (resume_cb, except_cb) ->
              fs.open filepath, 'r+', (e, fd) ->
                if e?
                  if e.code == 'ENOENT'
                    except_cb -> rs.java_throw rs.get_bs_class('Ljava/io/FileNotFoundException;'), "Could not open file #{filepath}"
                  else
                    except_cb -> throw e
                else
                  fd_obj = _this.get_field rs, 'Ljava/io/RandomAccessFile;fd'
                  fd_obj.set_field rs, 'Ljava/io/FileDescriptor;fd', fd
                  _this.$pos = 0
                  resume_cb()
        o 'getFilePointer()J', (rs, _this) -> gLong.fromNumber _this.$pos
        o 'length()J', (rs, _this) ->
            fd_obj = _this.get_field rs, 'Ljava/io/RandomAccessFile;fd'
            fd = fd_obj.get_field rs, 'Ljava/io/FileDescriptor;fd'
            gLong.fromNumber (stat_fd fd).size
        o 'seek(J)V', (rs, _this, pos) -> _this.$pos = pos.toNumber()
        o 'readBytes([BII)I', (rs, _this, byte_arr, offset, len) ->
            fd_obj = _this.get_field rs, 'Ljava/io/RandomAccessFile;fd'
            fd = fd_obj.get_field rs, 'Ljava/io/FileDescriptor;fd'
            # if at end of file, return -1.
            if _this.$pos >= fs.fstatSync(fd).size-1
              return -1
            buf = new Buffer len
            bytes_read = fs.readSync(fd, buf, 0, len, _this.$pos)
            byte_arr.array[offset+i] = buf.readUInt8(i) for i in [0...bytes_read] by 1
            _this.$pos += bytes_read
            return if bytes_read == 0 and len isnt 0 then -1 else bytes_read
        o 'writeBytes([BII)V', (rs, _this, byte_arr, offset, len) ->
            fd_obj = _this.get_field rs, 'Ljava/io/RandomAccessFile;fd'
            fd = fd_obj.get_field rs, 'Ljava/io/FileDescriptor;fd'
            _this.$pos += fs.writeSync(fd, new Buffer(byte_arr.array), offset,
                                       len, _this.$pos)
        o 'close0()V', (rs, _this) ->
            fd_obj = _this.get_field rs, 'Ljava/io/RandomAccessFile;fd'
            fd = fd_obj.get_field rs, 'Ljava/io/FileDescriptor;fd'
            rs.async_op (resume_cb, except_cb) ->
              fs.close fd, (err) ->
                if err
                  except_cb -> rs.java_throw rs.get_bs_class('Ljava/io/IOException;'), err.message
                else
                  fd_obj.set_field rs, 'Ljava/io/FileDescriptor;fd', -1
                  resume_cb()
      ]
      UnixFileSystem: [
        o 'canonicalize0(L!/lang/String;)L!/lang/String;', (rs, _this, jvm_path_str) ->
            js_str = jvm_path_str.jvm2js_str()
            rs.init_string path.resolve(path.normalize(js_str))
        o 'checkAccess(Ljava/io/File;I)Z', (rs, _this, file, access) ->
            filepath = file.get_field rs, 'Ljava/io/File;path'
            rs.async_op (resume_cb) ->
              stat_file filepath.jvm2js_str(), (stats) ->
                unless stats?
                  resume_cb false
                else
                  #XXX: Assuming we're owner/group/other. :)
                  # Shift access so it's present in owner/group/other.
                  # Then, AND with the actual mode, and check if the result is above 0.
                  # That indicates that the access bit we're looking for was set on
                  # one of owner/group/other.
                  mask = access | (access << 3) | (access << 6)
                  resume_cb((stats.mode & mask) > 0)
        o 'createDirectory(Ljava/io/File;)Z', (rs, _this, file) ->
            filepath = (file.get_field rs, 'Ljava/io/File;path').jvm2js_str()
            # Already exists.
            rs.async_op (resume_cb) ->
              stat_file filepath, (stat) ->
                if stat?
                  resume_cb false
                else
                  fs.mkdir filepath, (err) ->
                    resume_cb(if err? then false else true)
        o 'createFileExclusively(Ljava/lang/String;)Z', (rs, _this, path) ->  # OpenJDK version
            filepath = path.jvm2js_str()
            rs.async_op (resume_cb, except_cb) ->
              stat_file filepath, (stat) ->
                if stat?
                  resume_cb false
                else
                  fs.open filepath, 'w', (err, fd) ->
                    if err?
                      except_cb -> rs.java_throw rs.get_bs_class('Ljava/io/IOException;'), e.message
                    else
                      fs.close fd, (err) ->
                        if err?
                          except_cb -> rs.java_throw rs.get_bs_class('Ljava/io/IOException;'), e.message
                        else
                          resume_cb true
        o 'createFileExclusively(Ljava/lang/String;Z)Z', (rs, _this, path) ->  # Apple-java version
            filepath = path.jvm2js_str()
            rs.async_op (resume_cb, except_cb) ->
              stat_file filepath, (stat) ->
                if stat?
                  resume_cb false
                else
                  fs.open filepath, 'w', (err, fd) ->
                    if err?
                      except_cb -> rs.java_throw rs.get_bs_class('Ljava/io/IOException;'), e.message
                    else
                      fs.close fd, (err) ->
                        if err?
                          except_cb -> rs.java_throw rs.get_bs_class('Ljava/io/IOException;'), e.message
                        else
                          resume_cb true
        o 'delete0(Ljava/io/File;)Z', (rs, _this, file) ->
            # Delete the file or directory denoted by the given abstract
            # pathname, returning true if and only if the operation succeeds.
            # If file is a directory, it must be empty.
            filepath = (file.get_field rs, 'Ljava/io/File;path').jvm2js_str()
            rs.async_op (resume_cb, except_cb) ->
              stat_file filepath, (stats) ->
                unless stats?
                  resume_cb false
                else if stats.isDirectory()
                  fs.readdir filepath, (err, files) ->
                    if files.length > 0
                      resume_cb false
                    else
                      fs.rmdir filepath, (err) ->
                        resume_cb true
                else
                  fs.unlink filepath, (err) ->
                    resume_cb true
        o 'getBooleanAttributes0(Ljava/io/File;)I', (rs, _this, file) ->
            filepath = file.get_field rs, 'Ljava/io/File;path'
            rs.async_op (resume_cb) ->
              stat_file filepath.jvm2js_str(), (stats) ->
                unless stats?
                  resume_cb 0
                else if stats.isFile()
                  resume_cb 3
                else if stats.isDirectory()
                  resume_cb 5
                else
                  resume_cb 1
        o 'getLastModifiedTime(Ljava/io/File;)J', (rs, _this, file) ->
            filepath = file.get_field(rs, 'Ljava/io/File;path').jvm2js_str()
            rs.async_op (resume_cb) ->
              stat_file filepath, (stats) ->
                unless stats?
                  resume_cb gLong.ZERO, null
                else
                  resume_cb gLong.fromNumber (new Date(stats.mtime)).getTime(), null
        o 'setLastModifiedTime(Ljava/io/File;J)Z', (rs, _this, file, time) ->
            mtime = time.toNumber()
            atime = (new Date).getTime()
            filepath = file.get_field(rs, 'Ljava/io/File;path').jvm2js_str()
            rs.async_op (resume_cb) ->
              fs.utimes filepath, atime, mtime, (err) ->
                resume_cb true
        o 'getLength(Ljava/io/File;)J', (rs, _this, file) ->
            filepath = file.get_field rs, 'Ljava/io/File;path'
            rs.async_op (resume_cb) ->
              fs.stat filepath.jvm2js_str(), (err, stat) ->
                resume_cb gLong.fromNumber(if err? then 0 else stat.size), null
        #o 'getSpace(Ljava/io/File;I)J', (rs, _this, file, t) ->
        o 'list(Ljava/io/File;)[Ljava/lang/String;', (rs, _this, file) ->
            filepath = file.get_field rs, 'Ljava/io/File;path'
            rs.async_op (resume_cb) ->
              fs.readdir filepath.jvm2js_str(), (err, files) ->
                if err?
                  resume_cb null
                else
                  resume_cb new JavaArray(rs, rs.get_bs_class('[Ljava/lang/String;'),(rs.init_string(f) for f in files))
        o 'rename0(Ljava/io/File;Ljava/io/File;)Z', (rs, _this, file1, file2) ->
            file1path = (file1.get_field rs, 'Ljava/io/File;path').jvm2js_str()
            file2path = (file2.get_field rs, 'Ljava/io/File;path').jvm2js_str()
            rs.async_op (resume_cb) ->
              fs.rename file1path, file2path, (err) ->
                resume_cb(if err? then false else true)
        #o 'setLastModifiedTime(Ljava/io/File;J)Z', (rs, _this, file, time) ->
        o 'setPermission(Ljava/io/File;IZZ)Z', (rs, _this, file, access, enable, owneronly) ->
            filepath = (file.get_field rs, 'Ljava/io/File;path').jvm2js_str()
            # Access is equal to one of the following static fields:
            # * FileSystem.ACCESS_READ (0x04)
            # * FileSystem.ACCESS_WRITE (0x02)
            # * FileSystem.ACCESS_EXECUTE (0x01)
            # These are conveniently identical to their Unix equivalents, which
            # we have to convert to for Node.
            # XXX: Currently assuming that the above assumption holds across JCLs.

            if owneronly
              # Shift it 6 bits over into the 'owner' region of the access mode.
              access <<= 6
            else
              # Clone it into the 'owner' and 'group' regions.
              access |= (access << 6) | (access << 3)

            if not enable
              # Do an invert and we'll AND rather than OR.
              access = ~access

            # Returns true on success, false on failure.
            rs.async_op (resume_cb) ->
              # Fetch existing permissions on file.
              stat_file filepath, (stats) ->
                unless stats?
                  resume_cb false
                else
                  existing_access = stats.mode
                  # Apply mask.
                  access = if enable then existing_access | access else existing_access & access
                  # Set new permissions.
                  fs.chmod filepath, access, (err) ->
                    resume_cb(if err? then false else true)
        o 'setReadOnly(Ljava/io/File;)Z', (rs, _this, file) ->
            filepath = (file.get_field rs, 'Ljava/io/File;path').jvm2js_str()
            # We'll be unsetting write permissions.
            # Leading 0o indicates octal.
            mask = ~(0o222)
            rs.async_op (resume_cb) ->
              stat_file filepath, (stats) ->
                unless stats?
                  resume_cb false
                else
                  fs.chmod filepath, (stats.mode & mask), (err) ->
                    resume_cb(if err? then false else true)
      ]
    util:
      concurrent:
        atomic:
          AtomicLong: [
            o 'VMSupportsCS8()Z', -> true
          ]
      jar:
        JarFile: [
          o 'getMetaInfEntryNames()[L!/lang/String;', (rs) -> null  # we don't do verification
        ]
      ResourceBundle: [
        o 'getClassContext()[L!/lang/Class;', (rs) ->
            # XXX should walk up the meta_stack and fill in the array properly
            new JavaArray rs, rs.get_bs_class('[Ljava/lang/Class;'), [null,null,null]
      ]
      TimeZone: [
        o 'getSystemTimeZoneID(L!/lang/String;L!/lang/String;)L!/lang/String;', (rs, java_home, country) ->
            rs.init_string 'GMT' # XXX not sure what the local value is
        o 'getSystemGMTOffsetID()L!/lang/String;', (rs) ->
            null # XXX may not be correct
      ]
  sun:
    management:
      VMManagementImpl: [
        o 'getStartupTime()J', (rs) -> rs.startup_time
        o 'getVersion0()Ljava/lang/String;', (rs) -> rs.init_string "1.2", true
        o 'initOptionalSupportFields()V', (rs) ->
            # set everything to false
            field_names = [ 'compTimeMonitoringSupport', 'threadContentionMonitoringSupport',
              'currentThreadCpuTimeSupport', 'otherThreadCpuTimeSupport',
              'bootClassPathSupport', 'objectMonitorUsageSupport', 'synchronizerUsageSupport' ]
            vm_management_impl = rs.get_bs_class 'Lsun/management/VMManagementImpl;'
            for name in field_names
              vm_management_impl.static_put rs, name, 0
        o 'isThreadAllocatedMemoryEnabled()Z', -> false
        o 'isThreadContentionMonitoringEnabled()Z', -> false
        o 'isThreadCpuTimeEnabled()Z', -> false
        o 'getAvailableProcessors()I', -> 1
        o 'getProcessId()I', -> 1
      ]
      MemoryImpl: [
        o 'getMemoryManagers0()[Ljava/lang/management/MemoryManagerMXBean;', (rs) ->
            new JavaArray rs, rs.get_bs_class('[Lsun/management/MemoryManagerImpl;'), [] # XXX may want to revisit this 'NOP'
        o 'getMemoryPools0()[Ljava/lang/management/MemoryPoolMXBean;', (rs) ->
            new JavaArray rs, rs.get_bs_class('[Lsun/management/MemoryPoolImpl;'), [] # XXX may want to revisit this 'NOP'
      ]
    misc:
      VM: [
        o 'initialize()V', (rs) ->
            vm_cls = rs.get_bs_class 'Lsun/misc/VM;'
            # this only applies to Java 7
            return unless vm_cls.major_version >= 51
            # hack! make savedProps refer to the system props
            sys_cls = rs.get_bs_class('Ljava/lang/System;')
            props = sys_cls.static_get rs, 'props'
            vm_cls = rs.get_bs_class('Lsun/misc/VM;')
            vm_cls.static_put 'savedProps', props
      ]
      # TODO: Go down the rabbit hole and create a fast heap implementation
      # in JavaScript -- with and without typed arrays.
      Unsafe: [
        o 'addressSize()I', (rs, _this) -> 4 # either 4 or 8
        o 'allocateInstance(Ljava/lang/Class;)Ljava/lang/Object;', (rs, _this, cls) ->
            # This can trigger class initialization, so check if the class is
            # initialized.
            cls = cls.$cls
            if cls.is_initialized(rs)
              return new JavaObject rs, cls
            else
              rs.async_op (resume_cb, except_cb) ->
                cls.loader.initialize_class rs, cls.get_type(), (->resume_cb(new JavaObject rs, cls)), except_cb
        o 'allocateMemory(J)J', (rs, _this, size) ->
            next_addr = util.last(rs.mem_start_addrs)
            if DataView?
              rs.mem_blocks[next_addr] = new DataView new ArrayBuffer size
            else
              # 1 byte per block. Wasteful, terrible, etc... but good for now.
              # XXX: Stash allocation size here. Please hate me.
              rs.mem_blocks[next_addr] = size
              next_addr += 1
              for i in [0...size] by 1
                rs.mem_blocks[next_addr+i] = 0

            rs.mem_start_addrs.push(next_addr + size)
            return gLong.fromNumber(next_addr)
        o 'copyMemory(Ljava/lang/Object;JLjava/lang/Object;JJ)V', (rs, _this, src_base, src_offset, dest_base, dest_offset, num_bytes) ->
            unsafe_memcpy rs, src_base, src_offset, dest_base, dest_offset, num_bytes
        o 'setMemory(JJB)V', (rs, _this, address, bytes, value) ->
            block_addr = rs.block_addr(address)
            for i in [0...bytes] by 1
              if DataView?
                rs.mem_blocks[block_addr].setInt8(i, value)
              else
                rs.mem_blocks[block_addr+i] = value
            return
        o 'freeMemory(J)V', (rs, _this, address) ->
            if DataView?
              delete rs.mem_blocks[address.toNumber()]
            else
              # XXX: Size will be just before address.
              address = address.toNumber()
              num_blocks = rs.mem_blocks[address-1]
              for i in [0...num_blocks] by 1
                delete rs.mem_blocks[address+i]
              delete rs.mem_blocks[address-1]
              # Restore to the actual start addr where size was.
              address = address-1
            rs.mem_start_addrs.splice(rs.mem_start_addrs.indexOf(address), 1)
        o 'putLong(JJ)V', (rs, _this, address, value) ->
            block_addr = rs.block_addr(address)
            offset = address - block_addr
            # little endian
            if DataView?
              rs.mem_blocks[block_addr].setInt32(offset, value.getLowBits(), true)
              rs.mem_blocks[block_addr].setInt32(offset + 4, value.getHighBits, true)
            else
              # Break up into 8 bytes. Hurray!
              store_word = (rs_, address, word) ->
                # Little endian
                rs_.mem_blocks[address] = word & 0xFF
                rs_.mem_blocks[address+1] = (word >>> 8) & 0xFF
                rs_.mem_blocks[address+2] = (word >>> 16) & 0xFF
                rs_.mem_blocks[address+3] = (word >>> 24) & 0xFF

              store_word(rs, address, value.getLowBits())
              store_word(rs, address+4, value.getHighBits())
            return
        o 'getByte(J)B', (rs, _this, address) ->
            block_addr = rs.block_addr(address)
            if DataView?
              return rs.mem_blocks[block_addr].getInt8(address - block_addr)
            else
              # Blocks are bytes.
              return rs.mem_blocks[block_addr]
        o 'arrayBaseOffset(Ljava/lang/Class;)I', (rs, _this, cls) -> 0
        o 'arrayIndexScale(Ljava/lang/Class;)I', (rs, _this, cls) -> 1
        o 'compareAndSwapObject(Ljava/lang/Object;JLjava/lang/Object;Ljava/lang/Object;)Z', unsafe_compare_and_swap
        o 'compareAndSwapInt(Ljava/lang/Object;JII)Z', unsafe_compare_and_swap
        o 'compareAndSwapLong(Ljava/lang/Object;JJJ)Z', unsafe_compare_and_swap
        o 'ensureClassInitialized(Ljava/lang/Class;)V', (rs,_this,cls) ->
            rs.async_op (resume_cb, except_cb) ->
              # We modify resume_cb since this is a void function.
              cls.$cls.loader.initialize_class rs, cls.$cls.get_type(), (()->resume_cb()), except_cb
        o 'staticFieldOffset(Ljava/lang/reflect/Field;)J', (rs,_this,field) ->
            # we technically return a long, but it immediately gets casted to an int
            # hack: encode both the class and slot information in an integer
            #   this may cause collisions, but it seems to work ok
            jco = field.get_field rs, 'Ljava/lang/reflect/Field;clazz'
            slot = field.get_field rs, 'Ljava/lang/reflect/Field;slot'
            gLong.fromNumber(slot + jco.ref)
        o 'objectFieldOffset(Ljava/lang/reflect/Field;)J', (rs,_this,field) ->
            # see note about staticFieldOffset
            jco = field.get_field rs, 'Ljava/lang/reflect/Field;clazz'
            slot = field.get_field rs, 'Ljava/lang/reflect/Field;slot'
            gLong.fromNumber(slot + jco.ref)
        o 'staticFieldBase(Ljava/lang/reflect/Field;)Ljava/lang/Object;', (rs,_this,field) ->
            cls = field.get_field rs, 'Ljava/lang/reflect/Field;clazz'
            new JavaObject rs, cls.$cls
        o 'getBoolean(Ljava/lang/Object;J)Z', (rs, _this, obj, offset) ->
            obj.get_field_from_offset rs, offset
        o 'getBooleanVolatile(Ljava/lang/Object;J)Z', (rs, _this, obj, offset) ->
            obj.get_field_from_offset rs, offset
        o 'getDouble(Ljava/lang/Object;J)D', (rs, _this, obj, offset) ->
            obj.get_field_from_offset rs, offset
        o 'getDoubleVolatile(Ljava/lang/Object;J)D', (rs, _this, obj, offset) ->
            obj.get_field_from_offset rs, offset
        o 'getFloat(Ljava/lang/Object;J)F', (rs, _this, obj, offset) ->
            obj.get_field_from_offset rs, offset
        o 'getFloatVolatile(Ljava/lang/Object;J)F', (rs, _this, obj, offset) ->
            obj.get_field_from_offset rs, offset
        o 'getInt(Ljava/lang/Object;J)I', (rs, _this, obj, offset) ->
            obj.get_field_from_offset rs, offset
        o 'getIntVolatile(Ljava/lang/Object;J)I', (rs, _this, obj, offset) ->
            obj.get_field_from_offset rs, offset
        o 'getLong(Ljava/lang/Object;J)J', (rs, _this, obj, offset) ->
            obj.get_field_from_offset rs, offset
        o 'getLongVolatile(Ljava/lang/Object;J)J', (rs, _this, obj, offset) ->
            obj.get_field_from_offset rs, offset
        o 'getShort(Ljava/lang/Object;J)S', (rs, _this, obj, offset) ->
            obj.get_field_from_offset rs, offset
        o 'getShortVolatile(Ljava/lang/Object;J)S', (rs, _this, obj, offset) ->
            obj.get_field_from_offset rs, offset
        o 'getObject(Ljava/lang/Object;J)Ljava/lang/Object;', (rs,_this,obj,offset) ->
            obj.get_field_from_offset rs, offset
        o 'getObjectVolatile(Ljava/lang/Object;J)Ljava/lang/Object;', (rs,_this,obj,offset) ->
            obj.get_field_from_offset rs, offset
        o 'putDouble(Ljava/lang/Object;JD)V', (rs,_this,obj,offset,new_value) ->
            obj.set_field_from_offset rs, offset, new_value
        o 'putInt(Ljava/lang/Object;JI)V', (rs,_this,obj,offset,new_value) ->
            obj.set_field_from_offset rs, offset, new_value
        o 'putObject(Ljava/lang/Object;JLjava/lang/Object;)V', (rs,_this,obj,offset,new_obj) ->
            obj.set_field_from_offset rs, offset, new_obj
        o 'putObjectVolatile(Ljava/lang/Object;JLjava/lang/Object;)V', (rs,_this,obj,offset,new_obj) ->
            obj.set_field_from_offset rs, offset, new_obj
        o 'putOrderedObject(Ljava/lang/Object;JLjava/lang/Object;)V', (rs,_this,obj,offset,new_obj) ->
            obj.set_field_from_offset rs, offset, new_obj
        o 'defineClass(Ljava/lang/String;[BIILjava/lang/ClassLoader;Ljava/security/ProtectionDomain;)Ljava/lang/Class;', (rs, _this, name, bytes, offset, len, loader, pd) ->
            rs.async_op (success_cb, except_cb) ->
              native_define_class rs, name, bytes, offset, len, get_cl_from_jclo(rs, loader), success_cb, except_cb
        o 'pageSize()I', (rs) ->
            # Keep this in sync with sun/nio/ch/FileChannelImpl/initIDs for Mac
            # JCL compatibility.
            1024
        o 'throwException(Ljava/lang/Throwable;)V', (rs, _this, exception) ->
            # XXX: Copied from java_throw, except instead of making a new Exception,
            #      we already have one. May want to make this a helper method.
            my_sf = rs.curr_frame()
            my_sf.runner = ->
              my_sf.runner = null
              throw (new exceptions.JavaException(exception))
            throw exceptions.ReturnException
      ]
    nio:
      ch:
        FileChannelImpl: [
          # this poorly-named method actually specifies the page size for mmap
          # This is the Mac name for sun/misc/Unsafe::pageSize. Apparently they
          # wanted to ensure page sizes can be > 2GB...
          o 'initIDs()J', (rs) -> gLong.fromNumber(1024)  # arbitrary
          # Reports this file's size
          o 'size0(Ljava/io/FileDescriptor;)J', (rs, _this, fd_obj) ->
            fd = fd_obj.get_field rs, 'Ljava/io/FileDescriptor;fd'
            try
              return gLong.fromNumber(fs.fstatSync(fd).size)
            catch e
              rs.java_throw rs.get_bs_class('Ljava/io/IOException;'), 'Bad file descriptor.'
          o 'position0(Ljava/io/FileDescriptor;J)J', (rs, _this, fd, offset) ->
              parent = _this.get_field rs, 'Lsun/nio/ch/FileChannelImpl;parent'
              gLong.fromNumber(
                if offset.equals gLong.NEG_ONE
                  parent.$pos
                else
                  parent.$pos = offset.toNumber())
        ]
        FileDispatcher: [
          o 'init()V', (rs) -> # NOP
          o 'read0(Ljava/io/FileDescriptor;JI)I', (rs, fd_obj, address, len) ->
            fd = fd_obj.get_field rs, 'Ljava/io/FileDescriptor;fd'
            # read upto len bytes and store into mmap'd buffer at address
            block_addr = rs.block_addr(address)
            buf = new Buffer len
            bytes_read = fs.readSync(fd, buf, 0, len)
            if DataView?
              for i in [0...bytes_read] by 1
                rs.mem_blocks[block_addr].setInt8(i, buf.readInt8(i))
            else
              for i in [0...bytes_read] by 1
                rs.mem_blocks[block_addr+i] = buf.readInt8(i)
            return bytes_read
          o 'preClose0(Ljava/io/FileDescriptor;)V', (rs, fd_obj) ->
            # NOP, I think the actual fs.close is called later. If not, NBD.
        ]
        NativeThread: [
          o "init()V", (rs) -> # NOP
          o "current()J", (rs) ->
              # -1 means that we do not require signaling according to the
              # docs.
              gLong.fromNumber(-1)
        ]
    reflect:
      ConstantPool: [
        o 'getLongAt0(Ljava/lang/Object;I)J', (rs, _this, cp, idx) ->
            cp.get(idx).value
        o 'getUTF8At0(Ljava/lang/Object;I)Ljava/lang/String;', (rs, _this, cp, idx) ->
            rs.init_string cp.get(idx).value
      ]
      NativeMethodAccessorImpl: [
        o 'invoke0(Ljava/lang/reflect/Method;Ljava/lang/Object;[Ljava/lang/Object;)Ljava/lang/Object;', (rs,m,obj,params) ->
            cls = m.get_field rs, 'Ljava/lang/reflect/Method;clazz'
            slot = m.get_field rs, 'Ljava/lang/reflect/Method;slot'
            rs.async_op (resume_cb, except_cb) ->
              cls.$cls.loader.initialize_class rs, cls.$cls.get_type(), ((cls_obj) ->
                method = (method for sig, method of cls_obj.get_methods() when method.idx is slot)[0]
                my_sf = rs.curr_frame()
                rs.push obj unless method.access_flags.static
                # we don't get unboxing for free anymore, so we have to do it ourselves
                i = 0
                for p_type in method.param_types
                  p = params.array[i++]
                  if p_type in ['J','D']  # cat 2 primitives
                    if p?.ref?
                      primitive_value = p.get_field rs, p.cls.get_type()+'value'
                      rs.push2 primitive_value, null
                    else
                      rs.push2 p, null
                      i++  # skip past the null spacer
                  else if util.is_primitive_type(p_type)  # any other primitive
                    if p?.ref?
                      primitive_value = p.get_field rs, p.cls.get_type()+'value'
                      rs.push primitive_value
                    else
                      rs.push p
                  else
                    rs.push p
                # Reenter the RuntimeState loop, which should run our new StackFrame.
                # XXX: We use except_cb because it just replaces the runner function of the
                # current frame. We need a better story for calling Java threads through
                # native functions.
                except_cb ->
                  method.setup_stack(rs)
                  # Overwrite my runner.
                  my_sf.runner = ->
                    ret_type = m.get_field rs, 'Ljava/lang/reflect/Method;returnType'
                    descriptor = ret_type.$cls.get_type()
                    rv = rs.pop()
                    # pop again if it's a category 2 primitive type
                    rv = rs.pop() if descriptor in ['J','D']
                    rs.meta_stack().pop()
                    # wrap up primitives in their Object box
                    if util.is_primitive_type(descriptor) and descriptor != 'V'
                      rs.push ret_type.$cls.create_wrapper_object(rs, rv)
                    else
                      rs.push rv
              ), except_cb
      ]
      NativeConstructorAccessorImpl: [
        o 'newInstance0(Ljava/lang/reflect/Constructor;[Ljava/lang/Object;)Ljava/lang/Object;', (rs,m,params) ->
            cls = m.get_field rs, 'Ljava/lang/reflect/Constructor;clazz'
            slot = m.get_field rs, 'Ljava/lang/reflect/Constructor;slot'
            rs.async_op (resume_cb, except_cb) ->
              cls.$cls.loader.initialize_class rs, cls.$cls.get_type(), ((cls_obj)->
                method = (method for sig, method of cls_obj.get_methods() when method.idx is slot)[0]
                my_sf = rs.curr_frame()
                obj = new JavaObject rs, cls_obj
                rs.push obj
                rs.push_array(params.array) if params?
                # Reenter the RuntimeState loop, which should run our new StackFrame.
                # XXX: We use except_cb because it just replaces the runner function of the
                # current frame. We need a better story for calling Java threads through
                # native functions.
                except_cb ->
                  # Push the constructor's frame onto the stack.
                  method.setup_stack(rs)
                  # Overwrite my runner.
                  my_sf.runner = ->
                    rs.meta_stack().pop()
                    rs.push obj
              ), except_cb
      ]
      Reflection: [
        o 'getCallerClass(I)Ljava/lang/Class;', (rs, frames_to_skip) ->
            #TODO: disregard frames assoc. with java.lang.reflect.Method.invoke() and its implementation
            caller = rs.meta_stack().get_caller(frames_to_skip)
            cls = caller.method.cls
            return cls.get_class_object(rs)
        o 'getClassAccessFlags(Ljava/lang/Class;)I', (rs, class_obj) ->
            class_obj.$cls.access_byte
      ]

flatten_pkg = (pkg) ->
  result = {}
  pkg_name_arr = []
  rec_flatten = (pkg) ->
    for pkg_name, inner_pkg of pkg
      pkg_name_arr.push pkg_name
      if inner_pkg instanceof Array
        full_pkg_name = pkg_name_arr.join '/'
        for method in inner_pkg
          {fn_name, fn} = method
          # expand out the '!'s in the method names
          fn_name = fn_name.replace /!|;/g, do ->
            depth = 0
            (c) ->
              if c == '!' then pkg_name_arr[depth++]
              else if c == ';' then depth = 0; c
              else c
          full_name = "L#{full_pkg_name};::#{fn_name}"
          result[full_name] = fn
      else
        flattened_inner = rec_flatten inner_pkg
      pkg_name_arr.pop pkg_name
  rec_flatten pkg
  result

root.trapped_methods = flatten_pkg trapped_methods
root.native_methods = flatten_pkg native_methods
