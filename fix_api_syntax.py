import os
import re

api_dir = 'apps/web/app/api'
files_to_fix = [
    'projects/route.ts',
    'projects/[id]/traffic/route.ts',
    'projects/[id]/env/route.ts',
    'projects/[id]/link/route.ts',
    'projects/[id]/route.ts',
    'user/profile/route.ts',
    'user/accounts/route.ts'
]

def fix_file(filepath):
    full_path = os.path.join(api_dir, filepath)
    if not os.path.exists(full_path):
        return
        
    with open(full_path, 'r') as f:
        content = f.read()

    # Revert my bad sed attempts
    # We want to replace:
    # const { userId } = auth();
    #    
    #  
    # with just const { userId } = auth();
    
    # We also need to fix: if (!userId?.id) or session.user.id
    
    # Let's just do a clean rewrite for all the basic ones.
    
    # 1. Clean up imports
    content = re.sub(r'import { auth } from "@clerk/nextjs/server";\s*import { auth } from "@clerk/nextjs/server";', 'import { auth } from "@clerk/nextjs/server";', content)
    
    # 2. Fix the syntax errors
    # In projects/[id]/env/route.ts
    content = re.sub(r'userId:\s*userId\s*,\s*if\s*\(!project\)', 'userId: userId\n    });\n\n    if (!project)', content)
    content = re.sub(r'userId:\s*userId\s*if\s*\(!project\)', 'userId: userId\n    });\n\n    if (!project)', content)
    
    content = re.sub(r'const { userId } = auth\(\);\s*,\s*', 'const { userId } = auth();\n', content)
    content = re.sub(r'const { userId } = auth\(\);\s*if', 'const { userId } = auth();\n\n    if', content)
    
    # Remove hanging commas or space before if
    content = re.sub(r',\s*if \(!userId', '\n\n    if (!userId', content)
    
    # projects/[id]/link/route.ts issue
    content = re.sub(r"findOne\({ token\s*if", "findOne({ token });\n      if", content)
    
    # user/accounts/route.ts issue
    # const { userId } = auth();
    #    ,
    content = re.sub(r"const { userId } = auth\(\);\s*,\s*", "const { userId } = auth();\n", content)
    content = re.sub(r"if \(!userId\?\.id\)", "if (!userId)", content)

    # userId: userId } 
    # instead of userId: userId
    
    with open(full_path, 'w') as f:
        f.write(content)

for f in files_to_fix:
    fix_file(f)
