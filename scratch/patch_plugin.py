import os

path = r'C:\Users\Cristian\AppData\Local\Pub\Cache\hosted\pub.dev\flutter_system_ringtones-0.0.6\android\src\main\AndroidManifest.xml'

if os.path.exists(path):
    with open(path, 'r') as f:
        content = f.read()
    
    # Remove package="..."
    import re
    new_content = re.sub(r'package=".*?"', '', content)
    
    with open(path, 'w') as f:
        f.write(new_content)
    print("Patched successfully")
else:
    print("File not found")
