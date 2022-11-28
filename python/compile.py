
import shutil

archiveLocation = r''
archiveFormat = 'zip'
archiveSource = 'shaders'
shutil.make_archive(archiveLocation, archiveFormat, archiveSource)

compiledMessage = "Compiled " + archiveLocation + "." + archiveFormat
print(compiledMessage)
