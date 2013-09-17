from distutils.core import setup, Extension
from distutils.command.build_ext import build_ext
import os
import subprocess
import sys
import shutil

#os.environ['CXX'] = 'g++'
#os.environ['ARCHFLAGS'] ="-arch x86_64"

AAF_ROOT = os.environ.get("AAF_ROOT")

AAF_INCLUDE = os.path.join(AAF_ROOT,'include')
AAF_LIB = os.path.join(AAF_ROOT,'lib/debug')

AAF_COM = os.path.join(AAF_ROOT,'bin/debug')

ext_extra = {
    'include_dirs': ['headers',AAF_INCLUDE],
    'library_dirs': [AAF_LIB, AAF_COM],
    'libraries': ['aaflib','aafiid', 'com-api'],
}

if sys.platform.startswith('linux'):
    ext_extra['extra_link_args'] = ['-Wl,-R$ORIGIN']

print "AAF_ROOT =",AAF_ROOT

# Construct the modules that we find in the "build/cython" directory.
ext_modules = []
build_dir = os.path.abspath(os.path.join(__file__, '..', 'build', 'cython'))
for dirname, dirnames, filenames in os.walk(build_dir):
    for filename in filenames:
        if filename.startswith('.') or os.path.splitext(filename)[1] != '.cpp':
            continue

        path = os.path.join(dirname, filename)
        name = os.path.splitext(os.path.relpath(path, build_dir))[0].replace('/', '.')

        ext_modules.append(Extension(
            name,
            sources=[path],
            language="c++",
            **ext_extra
        ))
        
def get_com_api(debug=True, win_arch='64'):
    if sys.platform.startswith("win"):
        dir = os.path.join(AAF_ROOT,'win%s' % str(win_arch))
        if debug:
            dir = os.path.join(dir, "Debug")
        else:
            dir = os.path.join(dir, "Release")
            
        com_api = os.path.join(dir,'Refimpl', 'AAFCOAPI.dll')
        libaafintp =  os.path.join(dir,'Refimpl', 'aafext', 'AAFINTP.dll')
        libaafpgapi =  os.path.join(dir,'Refimpl', 'aafext', 'AAFPGAPI.dll')
        
        return com_api, libaafintp, libaafpgapi
    ext = '.so'
    if sys.platform == 'darwin':
        ext = '.dylib'
    dir = os.path.join(AAF_ROOT, 'bin')
    if debug:
        dir = os.path.join(dir, 'debug')
    
    com_api = os.path.join(dir, 'libcom-api' + ext)
    libaafintp = os.path.join(dir, 'aafext', 'libaafintp' + ext)
    libaafpgapi = os.path.join(dir, 'aafext', 'libaafpgapi' + ext)
    
    return com_api, libaafintp, libaafpgapi

def copy_com_api(debug=True):
    com_api, libaafintp, libaafpgapi = get_com_api(debug)
    print  com_api, libaafintp, libaafpgapi
    
    dir = os.path.dirname(__file__)
    
    # copy libcom-api
    basename = os.path.basename(com_api)
    dest = os.path.join(dir, 'aaf', basename)
    print com_api, '->', dest
    shutil.copy(com_api, dest)
    
    # create ext dir
    aafext_dir = os.path.join(dir, 'aaf', 'aafext')
    if not os.path.exists(aafext_dir):
        print 'creating', aafext_dir
        os.makedirs(aafext_dir)
        
    # copy libaafintp
    basename = os.path.basename(libaafintp)
    intp_dest = os.path.join(aafext_dir,basename)
    print libaafintp, '->', intp_dest
    shutil.copy(libaafintp, intp_dest)
    # copy libaafpgapi
    basename = os.path.basename(libaafpgapi)
    pgapi_dest = os.path.join(aafext_dir,basename)
    print libaafpgapi, '->', pgapi_dest
    shutil.copy(libaafpgapi, pgapi_dest)
    
    return dest,intp_dest, pgapi_dest

def name_tool_fix_com_api(path):
    
    cmd = ['install_name_tool', '-id', 'libcom-api.dylib', path]
    print subprocess.list2cmdline(cmd)
    subprocess.check_call(cmd)
    
    #'install_name_tool -id libcom-api.dylib aaf/libcom-api.dylib'

def install_name_tool(path):
    cmd = ['sh','fixup_bundle.sh', path]
    subprocess.check_call(cmd)
        
class build_pyaaf_ext(build_ext):
    def build_extensions(self):
        com_api, libaafintp, libaafpgapi = copy_com_api()
        if sys.platform == 'darwin':
            name_tool_fix_com_api(com_api)
        
        build_ext.build_extensions(self)
        
        if sys.platform == 'darwin':
            for item in self.get_outputs():
                install_name_tool(item)
        #print "done!"
        
com_api, libaafintp, libaafpgapi = get_com_api()
package_data = [os.path.basename(com_api)]
for item in (libaafintp, libaafpgapi):
    package_data.append(os.path.join('aafext', os.path.basename(item)))
        
package_data = {'aaf':package_data}

setup(

    name='aaf',
    version='0.2',
    description='Python Bindings for the Advanced Authoring Format (AAF)',
    
    author="Mark Reid",
    author_email="mindmark@gmail.com",
    
    url="https://github.com/markreidvfx/pyaaf",
    packages=['aaf'],
    ext_modules=ext_modules,
    cmdclass = {'build_ext':build_pyaaf_ext},
    package_data=package_data

)
