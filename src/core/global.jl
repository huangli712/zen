#
# project : pansy
# source  : global.jl
# author  : Li Huang (lihuang.dmft@gmail.com)
# status  : stable
# comment :
#
# last modified: 2021/01/11
#

"""
    I32 and I64

Alias of integer type
"""
const I32 = Int32
const I64 = Int64

"""
    F32 and F64

Alias of float type
"""
const F32 = Float32
const F64 = Float64

"""
    C32 and C64

Alias of complex type
"""
const C32 = ComplexF32
const C64 = ComplexF64

"""
    __LIBNAME__

Name of this julia package
"""
const __LIBNAME__ = "ZEN Framework"

"""
    __VERSION__

Version of this julia package
"""
const __VERSION__ = "0.0.6@devel"

"""
    __RELEASE__

Release date of this julia package
"""
const __RELEASE__ = "2021/01"

"""
    __AUTHORS__

Core authors of this julia package
"""
const __AUTHORS__ = [(name = "Li Huang", email = "lihuang.dmft@gmail.com")]