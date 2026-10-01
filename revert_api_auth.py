import os
import re

def fix_api_file(filepath):
    if not os.path.exists(filepath):
        print(f"Skipping {filepath}")
        return
        
    with open(filepath, 'r') as f:
        content = f.read()
        
    # Replace import
    content = content.replace('import { auth } from "@clerk/nextjs/server";', 'import { auth } from "@/lib/auth";\nimport { headers } from "next/headers";')
    
    # In some files I might have imported headers already
    content = re.sub(r'import { headers } from "next/headers";\s*import { headers } from "next/headers";', 'import { headers } from "next/headers";', content)

    # Replace let/const { userId } = await auth();
    content = re.sub(r'(const|let) \{ userId \} = await auth\(\);', r'\1 session = await auth.api.getSession({ headers: headers() });\n    \1 userId = session?.user?.id;', content)
    content = re.sub(r'(const|let) \{ userId \} = auth\(\);', r'\1 session = await auth.api.getSession({ headers: headers() });\n    \1 userId = session?.user?.id;', content)

    with open(filepath, 'w') as f:
        f.write(content)

base = 'apps/web/app/api'
files = [
    f'{base}/projects/route.ts',
    f'{base}/projects/[id]/route.ts',
    f'{base}/projects/[id]/traffic/route.ts',
    f'{base}/projects/[id]/env/route.ts',
    f'{base}/projects/[id]/link/route.ts',
    f'{base}/user/accounts/route.ts'
]

for f in files:
    fix_api_file(f)

print("Done")
