import os
import re

def fix_client_file(filepath):
    if not os.path.exists(filepath):
        return
        
    with open(filepath, 'r') as f:
        content = f.read()
        
    # Replace import
    content = content.replace('import { useUser } from "@clerk/nextjs";', 'import { authClient } from "@/lib/auth-client";')
    content = content.replace('import { useUser, useClerk } from "@clerk/nextjs";', 'import { authClient } from "@/lib/auth-client";')
    
    # In dashboard/page.tsx, I used useClerk for signOut maybe?
    # Let's replace signOut calls
    content = re.sub(r'const \{ signOut \} = useClerk\(\);', 'const signOut = () => authClient.signOut();', content)

    # Replace hook
    content = content.replace('const { user: session, isLoaded: isPending } = useUser();', 'const { data: session, isPending } = authClient.useSession();')

    with open(filepath, 'w') as f:
        f.write(content)

files = [
    'apps/web/app/page.tsx',
    'apps/web/app/dashboard/page.tsx',
    'apps/web/app/dashboard/project/[id]/page.tsx',
    'apps/web/app/cli/auth/page.tsx'
]

for f in files:
    fix_client_file(f)

print("Done")
